import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../services/file_transfer_service.dart';
import '../../state/app_state.dart';
import 'app_feedback.dart';
import 'export_actions.dart';

enum _ExportChoice {
  productsCsv('Produits', 'CSV', Icons.table_view_rounded),
  productsExcel('Produits', 'Excel', Icons.grid_on_rounded),
  clientsCsv('Clients', 'CSV', Icons.people_outline_rounded),
  clientsExcel('Clients', 'Excel', Icons.people_alt_outlined),
  movementsCsv('Mouvements', 'CSV', Icons.swap_vert_rounded),
  movementsExcel('Mouvements', 'Excel', Icons.view_list_rounded);

  const _ExportChoice(this.dataLabel, this.formatLabel, this.icon);

  final String dataLabel;
  final String formatLabel;
  final IconData icon;
}

/// Propose les exports locaux des trois listes principales.
///
/// Aucun fichier ne quitte le téléphone sans l'action de l'utilisateur.
Future<void> showDataExportSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<_ExportChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Exporter les données',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Choisissez une liste et un format. Le fichier sera généré '
              'localement à partir de vos données.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final choice in _ExportChoice.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExportOptionTile(
                  choice: choice,
                  onTap: () => Navigator.of(sheetContext).pop(choice),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'CSV : compatible avec la plupart des tableurs. '
              'Excel : fichier .xlsx mis en forme.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    },
  );

  if (choice == null || !context.mounted) return;

  final appState = context.read<AppState>();
  final exportService = appState.exportService;
  final timestamp = DateTime.now();
  late final Uint8List bytes;
  late final String fileName;
  late final String mimeType;

  switch (choice) {
    case _ExportChoice.productsCsv:
      bytes = exportService.productsCsv(appState.products);
      fileName = 'wanma_produits_${_stamp(timestamp)}.csv';
      mimeType = FileTransferService.mimeTypeForExtension('csv');
    case _ExportChoice.productsExcel:
      bytes = exportService.productsExcel(appState.products);
      fileName = 'wanma_produits_${_stamp(timestamp)}.xlsx';
      mimeType = FileTransferService.mimeTypeForExtension('xlsx');
    case _ExportChoice.clientsCsv:
      bytes = exportService.clientsCsv(appState.clients);
      fileName = 'wanma_clients_${_stamp(timestamp)}.csv';
      mimeType = FileTransferService.mimeTypeForExtension('csv');
    case _ExportChoice.clientsExcel:
      bytes = exportService.clientsExcel(appState.clients);
      fileName = 'wanma_clients_${_stamp(timestamp)}.xlsx';
      mimeType = FileTransferService.mimeTypeForExtension('xlsx');
    case _ExportChoice.movementsCsv:
      bytes = exportService.movementsCsv(appState.movements);
      fileName = 'wanma_mouvements_${_stamp(timestamp)}.csv';
      mimeType = FileTransferService.mimeTypeForExtension('csv');
    case _ExportChoice.movementsExcel:
      bytes = exportService.movementsExcel(appState.movements);
      fileName = 'wanma_mouvements_${_stamp(timestamp)}.xlsx';
      mimeType = FileTransferService.mimeTypeForExtension('xlsx');
  }

  if (!context.mounted) return;
  await chooseExportDestination(
    context,
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
    title: 'Export prêt',
  );
}

String _stamp(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}${two(value.month)}${two(value.day)}_'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}';
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({required this.choice, required this.onTap});

  final _ExportChoice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final excel = choice.formatLabel == 'Excel';
    final color = excel ? AppColors.success : AppColors.primary;
    final background = excel ? AppColors.successLight : AppColors.primaryLight;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(choice.icon, size: 19, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  '${choice.dataLabel} en ${choice.formatLabel}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '.${excel ? 'xlsx' : 'csv'}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Conseils affichés avant de quitter un écran d'export.
void showExportPrivacyNote(BuildContext context) {
  AppFeedback.info(
    context,
    'Vos exports sont générés sur ce téléphone. Wanma n’envoie rien sur Internet.',
  );
}
