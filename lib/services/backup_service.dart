import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';

/// Informations lisibles extraites d'une sauvegarde valide.
class BackupInfo {
  const BackupInfo({
    required this.createdAt,
    required this.schemaVersion,
    required this.productCount,
    required this.clientCount,
    required this.movementCount,
    required this.sizeBytes,
  });

  final DateTime? createdAt;
  final int schemaVersion;
  final int productCount;
  final int clientCount;
  final int movementCount;
  final int sizeBytes;
}

/// Sauvegarde prête à être enregistrée par l'utilisateur.
class BackupFile {
  const BackupFile({
    required this.bytes,
    required this.fileName,
    required this.info,
  });

  final Uint8List bytes;
  final String fileName;
  final BackupInfo info;
}

/// Sauvegarde et restauration locales de la base SQLite.
///
/// Le fichier `.wanma` est un conteneur JSON contenant la base encodée en
/// base64, sa version de schéma et une empreinte SHA-256. Cette empreinte
/// détecte les fichiers corrompus ou modifiés avant restauration.
class BackupService {
  BackupService(this._database);

  final AppDatabase _database;

  static const List<int> _sqliteHeader = <int>[
    83,
    81,
    76,
    105,
    116,
    101,
    32,
    102,
    111,
    114,
    109,
    97,
    116,
    32,
    51,
    0,
  ];
  static const int _maxBackupBytes = 200 * 1024 * 1024;

  /// Crée une sauvegarde cohérente. La base est brièvement fermée le temps de
  /// copier son fichier principal, puis immédiatement rouverte.
  Future<BackupFile> createBackup() async {
    final db = await _database.database;
    final sourcePath = db.path;
    final counts = await _readCounts(db);
    final now = DateTime.now();
    final tempPath = _tempPath('backup');
    final temp = File(tempPath);
    Uint8List databaseBytes;

    await _database.checkpoint();
    await _database.close();
    try {
      await File(sourcePath).copy(tempPath);
      databaseBytes = await temp.readAsBytes();
    } finally {
      await _database.reopen();
      if (await temp.exists()) {
        await temp.delete();
      }
    }

    if (databaseBytes.length < _sqliteHeader.length) {
      throw const AppException(
        'La copie de la base est vide. Sauvegarde annulée.',
      );
    }

    final checksum = sha256.convert(databaseBytes).toString();
    final payload = <String, Object?>{
      'format': AppConstants.backupFormat,
      'formatVersion': AppConstants.backupFormatVersion,
      'schemaVersion': AppConstants.databaseVersion,
      'createdAt': now.toIso8601String(),
      'checksum': checksum,
      'counts': counts,
      'database': base64Encode(databaseBytes),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    return BackupFile(
      bytes: bytes,
      fileName:
          'wanma_sauvegarde_${AppFormatters.fileTimestamp(now)}.${AppConstants.backupExtension}',
      info: BackupInfo(
        createdAt: now,
        schemaVersion: AppConstants.databaseVersion,
        productCount: counts['products'] ?? 0,
        clientCount: counts['clients'] ?? 0,
        movementCount: counts['movements'] ?? 0,
        sizeBytes: bytes.length,
      ),
    );
  }

  /// Contrôle le conteneur, l'empreinte, l'en-tête SQLite et l'intégrité réelle
  /// de la base avant toute modification des données actuelles.
  Future<BackupInfo> validateBackup(Uint8List bytes) async {
    final databaseBytes = _decodeEnvelope(bytes);
    return _validateDatabaseBytes(databaseBytes);
  }

  /// Restaure une sauvegarde après validation. Une copie de secours de la base
  /// actuelle est créée avant remplacement et utilisée en cas d'échec.
  Future<BackupInfo> restoreBackup(Uint8List bytes) async {
    final validated = await validateBackup(bytes);
    final databaseBytes = _decodeEnvelope(bytes);
    final currentPath = (await _database.database).path;
    final directory = Directory(p.dirname(currentPath));
    final restoreFile = File(
      p.join(
        directory.path,
        '.wanma_restore_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );

    await restoreFile.writeAsBytes(databaseBytes, flush: true);

    final rollbackFile = File(
      p.join(
        directory.path,
        '.wanma_rollback_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );

    var closed = false;
    try {
      await _database.checkpoint();
      await _database.close();
      closed = true;

      final currentFile = File(currentPath);
      if (await currentFile.exists()) {
        await currentFile.copy(rollbackFile.path);
      }

      await _deleteSidecarFiles(currentPath);
      await restoreFile.copy(currentPath);

      // Rouvre et applique le cas échéant les migrations de version.
      final restoredDb = await _database.reopen();
      await _checkIntegrity(restoredDb);
      await _assertCoreTables(restoredDb);

      if (await rollbackFile.exists()) {
        await rollbackFile.delete();
      }
      return validated;
    } catch (error) {
      // Tente de remettre en place la base précédente. Une erreur de
      // restauration ne doit jamais laisser une base partielle.
      try {
        if (!closed) {
          await _database.checkpoint();
          await _database.close();
        }
        await _deleteSidecarFiles(currentPath);
        if (await rollbackFile.exists()) {
          await rollbackFile.copy(currentPath);
        }
        await _database.reopen();
      } catch (_) {
        // L'erreur d'origine reste la plus utile pour l'utilisateur.
      }
      throw AppException(
        'La restauration a échoué. La base précédente a été conservée lorsque '
        'cela était possible.',
        cause: error,
      );
    } finally {
      if (await restoreFile.exists()) {
        await restoreFile.delete();
      }
      if (await rollbackFile.exists()) {
        try {
          await rollbackFile.delete();
        } catch (_) {
          // Un fichier de secours résiduel ne bloque pas l'application.
        }
      }
    }
  }

  Uint8List _decodeEnvelope(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const AppException('Le fichier de sauvegarde est vide.');
    }
    if (bytes.length > _maxBackupBytes) {
      throw const AppException('Ce fichier de sauvegarde est trop volumineux.');
    }

    late Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Racine JSON invalide');
      }
      data = decoded;
    } catch (_) {
      throw const AppException(
        'Ce fichier n’est pas une sauvegarde Wanma valide.',
      );
    }

    if (data['format'] != AppConstants.backupFormat) {
      throw const AppException('Format de sauvegarde Wanma non reconnu.');
    }
    final formatVersion = data['formatVersion'];
    if (formatVersion is! int ||
        formatVersion > AppConstants.backupFormatVersion) {
      throw const AppException(
        'Cette sauvegarde provient d’une version plus récente de Wanma.',
      );
    }
    final schemaVersion = data['schemaVersion'];
    if (schemaVersion is! int || schemaVersion < 1) {
      throw const AppException('Version de base de données invalide.');
    }
    if (schemaVersion > AppConstants.databaseVersion) {
      throw const AppException(
        'Cette sauvegarde a été créée avec une version plus récente de Wanma. '
        'Mettez l’application à jour avant de la restaurer.',
      );
    }

    final encodedDatabase = data['database'];
    final checksum = data['checksum'];
    if (encodedDatabase is! String ||
        encodedDatabase.isEmpty ||
        checksum is! String ||
        checksum.isEmpty) {
      throw const AppException('La sauvegarde est incomplète ou endommagée.');
    }

    late Uint8List databaseBytes;
    try {
      databaseBytes = base64Decode(encodedDatabase);
    } catch (_) {
      throw const AppException('Les données de la sauvegarde sont illisibles.');
    }

    final actualChecksum = sha256.convert(databaseBytes).toString();
    if (actualChecksum != checksum) {
      throw const AppException(
        'La sauvegarde est corrompue ou a été modifiée. '
        'L’empreinte de sécurité ne correspond pas.',
      );
    }
    if (databaseBytes.length < _sqliteHeader.length) {
      throw const AppException('Le contenu de la base est invalide.');
    }
    for (var i = 0; i < _sqliteHeader.length; i++) {
      if (databaseBytes[i] != _sqliteHeader[i]) {
        throw const AppException(
          'Le fichier ne contient pas une base SQLite Wanma valide.',
        );
      }
    }
    return databaseBytes;
  }

  Future<BackupInfo> _validateDatabaseBytes(Uint8List databaseBytes) async {
    final currentPath = (await _database.database).path;
    final temp = File(_tempPath('validation'));
    await temp.writeAsBytes(databaseBytes, flush: true);
    Database? validationDb;
    try {
      validationDb = await _database.factory.openDatabase(
        temp.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      await _checkIntegrity(validationDb);
      await _assertCoreTables(validationDb);
      final versionRows = await validationDb.rawQuery('PRAGMA user_version');
      final fileVersion = versionRows.isEmpty
          ? 0
          : (versionRows.first.values.first as num?)?.toInt() ?? 0;
      if (fileVersion > AppConstants.databaseVersion) {
        throw const AppException(
          'Cette base provient d’une version plus récente de Wanma.',
        );
      }
      final counts = await _readCounts(validationDb);
      final parentExists = await Directory(p.dirname(currentPath)).exists();
      if (!parentExists) {
        throw const AppException(
          'Le dossier de données de l’application est inaccessible.',
        );
      }
      return BackupInfo(
        createdAt: null,
        schemaVersion: fileVersion,
        productCount: counts['products'] ?? 0,
        clientCount: counts['clients'] ?? 0,
        movementCount: counts['movements'] ?? 0,
        sizeBytes: databaseBytes.length,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(
        'La base contenue dans la sauvegarde est illisible ou corrompue.',
        cause: error,
      );
    } finally {
      if (validationDb != null && validationDb.isOpen) {
        await validationDb.close();
      }
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  Future<void> _checkIntegrity(Database db) async {
    final result = await db.rawQuery('PRAGMA integrity_check');
    if (result.isEmpty) {
      throw const AppException('La vérification d’intégrité a échoué.');
    }
    final values = result.first.values.map((value) => value.toString());
    if (!values.contains('ok')) {
      throw const AppException(
        'La base de données présente des incohérences et ne peut pas être '
        'restaurée.',
      );
    }
  }

  Future<void> _assertCoreTables(DatabaseExecutor db) async {
    const requiredTables = <String>{
      'products',
      'clients',
      'stock_movements',
      'stock_out_details',
    };
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = rows.map((row) => row['name']).whereType<String>().toSet();
    if (!requiredTables.every(tables.contains)) {
      throw const AppException(
        'Cette sauvegarde ne contient pas toutes les tables Wanma requises.',
      );
    }
  }

  Future<Map<String, int>> _readCounts(DatabaseExecutor db) async {
    Future<int> count(String table) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
      return (rows.first['total'] as num?)?.toInt() ?? 0;
    }

    return <String, int>{
      'products': await count('products'),
      'clients': await count('clients'),
      'movements': await count('stock_movements'),
    };
  }

  String _tempPath(String prefix) {
    final path = _database.path;
    final directory = path == null
        ? Directory.systemTemp.path
        : p.dirname(path);
    return p.join(
      directory,
      '.wanma_${prefix}_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  }

  Future<void> _deleteSidecarFiles(String databasePath) async {
    for (final suffix in <String>['-wal', '-shm']) {
      final sidecar = File('$databasePath$suffix');
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
  }
}
