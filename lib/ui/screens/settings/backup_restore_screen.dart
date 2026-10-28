import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/backup_service.dart';
import '../../../services/file_transfer_service.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/export_actions.dart';
import '../../widgets/form_sections.dart';

/// Sauvegarde et restauration manuelles du fichier local `.wanma`.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _creating = false;
  bool _checking = false;
  bool _restoring = false;
  Uint8List? _selectedBytes;
  String? _selectedFileName;
  BackupInfo? _selectedInfo;

  Future<void> _createBackup() async {
    if (_creating || _restoring) return;
    final appState = context.read<AppState>();
    setState(() => _creating = true);
    try {
      final backup = await appState.createBackup();
      if (!mounted) return;
      await chooseExportDestination(
        context,
        bytes: backup.bytes,
        fileName: backup.fileName,
        mimeType: FileTransferService.mimeTypeForExtension('wanma'),
        title: 'Sauvegarde créée',
      );
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _pickBackup() async {
    if (_checking || _restoring) return;
    setState(() => _checking = true);
    try {
      final picked = await FileTransferService.pickBackupFile();
      if (picked == null || !mounted) return;
      final info = await context.read<AppState>().validateBackup(picked.bytes);
      if (!mounted) return;
      setState(() {
        _selectedBytes = picked.bytes;
        _selectedFileName = picked.name;
        _selectedInfo = info;
      });
      AppFeedback.success(
        context,
        'Sauvegarde vérifiée. Vous pouvez restaurer.',
      );
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _restore() async {
    final bytes = _selectedBytes;
    if (bytes == null || _restoring) return;
    final info = _selectedInfo;
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Remplacer mes données ?',
      message:
          'Toutes les données actuelles seront remplacées par la sauvegarde '
          '${_selectedFileName ?? ''}'
          '${info == null ? '' : ' (${info.productCount} produits, '
                    '${info.clientCount} clients, ${info.movementCount} mouvements)'}. '
          'Cette action ne peut pas être annulée.',
      confirmLabel: 'Restaurer',
      destructive: true,
      icon: Icons.restore_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _restoring = true);
    try {
      final restoredInfo = await context.read<AppState>().restoreBackup(bytes);
      if (!mounted) return;
      setState(() {
        _selectedBytes = null;
        _selectedFileName = null;
        _selectedInfo = null;
      });
      AppFeedback.success(
        context,
        'Restauration terminée : ${restoredInfo.productCount} produits, '
        '${restoredInfo.clientCount} clients et '
        '${restoredInfo.movementCount} mouvements.',
      );
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final busy = _creating || _checking || _restoring;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
          children: <Widget>[
            Text(
              'Sauvegarde et restauration',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 3),
            Text(
              'Une copie de vos données, toujours sous votre contrôle.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 16),
            AppCard(
              color: AppColors.ink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.amber,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Vos données, votre téléphone',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'La sauvegarde est un fichier .wanma local, '
                              'protégé par une empreinte SHA-256.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      _HeaderCount(
                        label: 'Produits',
                        value: '${appState.products.length}',
                      ),
                      const SizedBox(width: 8),
                      _HeaderCount(
                        label: 'Clients',
                        value: '${appState.clients.length}',
                      ),
                      const SizedBox(width: 8),
                      _HeaderCount(
                        label: 'Mouvements',
                        value: '${appState.movements.length}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Sauvegarder les données',
              subtitle:
                  'Créez une copie complète et conservez-la hors du téléphone.',
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.cobaltSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.save_alt_rounded,
                          color: AppColors.cobalt,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Exporter une copie de votre base de données et de '
                          'vos fichiers.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: busy ? null : _createBackup,
                    icon: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shield_rounded),
                    label: Text(
                      _creating
                          ? 'Création en cours...'
                          : 'Créer une sauvegarde',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Restaurer les données',
              subtitle:
                  'Importez une sauvegarde existante. Elle sera contrôlée '
                  'avant tout remplacement.',
            ),
            AppCard(
              borderColor: _selectedInfo != null
                  ? AppColors.mint.withValues(alpha: 0.35)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selectedInfo != null
                              ? AppColors.mintSoft
                              : AppColors.paper,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _selectedInfo != null
                              ? Icons.verified_rounded
                              : Icons.settings_backup_restore_rounded,
                          color: _selectedInfo != null
                              ? AppColors.mint
                              : AppColors.muted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedInfo == null
                              ? 'Choisissez un fichier .wanma depuis le '
                                    'stockage du téléphone.'
                              : 'Sauvegarde vérifiée et prête à être '
                                    'restaurée.',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedInfo != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.mintSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _selectedFileName ?? 'Sauvegarde',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mint,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedInfo!.productCount} produits · '
                            '${_selectedInfo!.clientCount} clients · '
                            '${_selectedInfo!.movementCount} mouvements · '
                            '${_formatBytes(_selectedInfo!.sizeBytes)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.mint,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _pickBackup,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open_rounded),
                    label: Text(
                      _checking
                          ? 'Vérification...'
                          : 'Choisir une sauvegarde à restaurer',
                    ),
                  ),
                  if (_selectedInfo != null) ...<Widget>[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: busy ? null : _restore,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      icon: _restoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.restore_rounded),
                      label: Text(
                        _restoring
                            ? 'Restauration...'
                            : 'Restaurer cette sauvegarde',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const InfoBanner(
              text:
                  'La restauration remplace toutes les données actuelles. En cas '
                  'de fichier corrompu, Wanma vérifie l’empreinte et l’intégrité '
                  'SQLite avant de toucher à votre base. Un échec conserve la '
                  'version précédente.',
              icon: Icons.lock_outline_rounded,
              color: AppColors.cobalt,
              backgroundColor: AppColors.cobaltSoft,
            ),
            const SizedBox(height: 14),
            const InfoBanner(
              text:
                  'Le code PIN n’est pas inclus dans la sauvegarde. Il reste '
                  'attaché à ce téléphone. Conservez le fichier .wanma dans un '
                  'endroit sûr : il contient des données commerciales sensibles.',
              icon: Icons.password_rounded,
              color: AppColors.amberDark,
              backgroundColor: AppColors.amberSoft,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes octets';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

class _HeaderCount extends StatelessWidget {
  const _HeaderCount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
