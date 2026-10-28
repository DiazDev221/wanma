import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Fichier choisi par l'utilisateur pour une restauration.
class PickedFileData {
  const PickedFileData({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Enregistrement et partage de fichiers via les interfaces Android.
///
/// Aucune opération réseau n'est effectuée : le partage ouvre uniquement le
/// sélecteur natif du téléphone.
abstract final class FileTransferService {
  static Future<Uri?> saveFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? dialogTitle,
  }) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle ?? 'Enregistrer le fichier',
    );
  }

  static Future<PickedFileData?> pickBackupFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choisir une sauvegarde Wanma',
      type: FileType.custom,
      allowedExtensions: <String>['wanma'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedFileData(name: file.name, bytes: bytes);
  }

  static Future<void> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final directory = await getTemporaryDirectory();
    final safeName = p.basename(fileName).replaceAll(RegExp(r'[^\w.\-]'), '_');
    final file = File(p.join(directory.path, safeName));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Partager depuis Wanma',
        subject: fileName,
        files: <XFile>[XFile(file.path, mimeType: mimeType, name: safeName)],
      ),
    );
  }

  static String mimeTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'csv':
        return 'text/csv';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pdf':
        return 'application/pdf';
      case 'wanma':
        return 'application/octet-stream';
      default:
        return 'application/octet-stream';
    }
  }
}
