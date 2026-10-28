import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../services/file_transfer_service.dart';
import 'app_feedback.dart';

enum _FileAction { save, share }

/// Propose d'enregistrer ou de partager un fichier généré localement.
///
/// L'enregistrement ouvre le sélecteur de fichiers Android ; le partage ouvre
/// le menu natif. Aucune donnée n'est transmise automatiquement.
Future<void> chooseExportDestination(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String title = 'Fichier prêt',
}) async {
  final action = await showModalBottomSheet<_FileAction>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_FileAction.save),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Enregistrer sur l’appareil'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_FileAction.share),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Partager'),
              ),
              const SizedBox(height: 10),
              Text(
                'Le fichier reste sur votre téléphone. Wanma ne l’envoie jamais '
                'automatiquement sur Internet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;

  try {
    if (action == _FileAction.save) {
      final uri = await FileTransferService.saveFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        dialogTitle: 'Enregistrer $fileName',
      );
      if (!context.mounted) return;
      if (uri != null) {
        AppFeedback.success(context, 'Fichier enregistré avec succès.');
      }
    } else {
      await FileTransferService.shareFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    }
  } catch (error) {
    if (context.mounted) {
      AppFeedback.error(
        context,
        Exception('Impossible de traiter le fichier. Réessayez.'),
      );
    }
  }
}
