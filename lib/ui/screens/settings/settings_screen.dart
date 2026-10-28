import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/data_export_sheet.dart';
import '../../widgets/form_sections.dart';
import '../help_screen.dart';
import 'backup_restore_screen.dart';

/// Paramètres locaux : sécurité, exports, stockage et informations.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _enablePin() async {
    final values = await _showPinDialog(
      title: 'Activer le verrouillage',
      message:
          'Choisissez un code à 4 chiffres. Il sera demandé à l’ouverture de '
          'Wanma et après 15 secondes en arrière-plan.',
      requireConfirm: true,
    );
    if (values == null || !mounted) return;
    await _runSecurityAction(
      () => context.read<AppState>().enablePin(values[0]),
      success: 'Le verrouillage par code PIN est activé.',
    );
  }

  Future<void> _changePin() async {
    final values = await _showPinDialog(
      title: 'Changer le code PIN',
      message: 'Saisissez votre code actuel puis le nouveau code.',
      requireCurrent: true,
      requireConfirm: true,
    );
    if (values == null || !mounted) return;
    final changed = await context.read<AppState>().changePin(
      currentPin: values[0],
      newPin: values[1],
    );
    if (!mounted) return;
    if (changed) {
      AppFeedback.success(context, 'Votre code PIN a été modifié.');
    } else {
      AppFeedback.error(
        context,
        Exception('Le code PIN actuel est incorrect.'),
      );
    }
  }

  Future<void> _disablePin() async {
    final values = await _showPinDialog(
      title: 'Désactiver le code PIN',
      message:
          'Confirmez votre code actuel. Sans code, toute personne ayant accès '
          'au téléphone pourra ouvrir Wanma.',
      requireCurrent: true,
    );
    if (values == null || !mounted) return;
    final disabled = await context.read<AppState>().disablePin(values[0]);
    if (!mounted) return;
    if (disabled) {
      AppFeedback.success(context, 'Le verrouillage a été désactivé.');
    } else {
      AppFeedback.error(
        context,
        Exception('Le code PIN actuel est incorrect.'),
      );
    }
  }

  Future<void> _runSecurityAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) AppFeedback.success(context, success);
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>?> _showPinDialog({
    required String title,
    required String message,
    bool requireCurrent = false,
    bool requireConfirm = false,
  }) {
    final currentController = TextEditingController();
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.lock_outline_rounded),
          title: Text(title),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (requireCurrent)
                    _PinField(
                      controller: currentController,
                      label: 'Code actuel',
                      autofocus: true,
                    ),
                  if (requireCurrent) const SizedBox(height: 10),
                  _PinField(
                    controller: pinController,
                    label: requireCurrent ? 'Nouveau code' : 'Code PIN',
                    autofocus: !requireCurrent,
                  ),
                  if (requireConfirm) ...<Widget>[
                    const SizedBox(height: 10),
                    _PinField(
                      controller: confirmController,
                      label: 'Confirmer le code',
                      validator: (value) {
                        if (value != pinController.text) {
                          return 'Les deux codes ne correspondent pas.';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                currentController.dispose();
                pinController.dispose();
                confirmController.dispose();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final values = <String>[
                    if (requireCurrent) currentController.text,
                    pinController.text,
                  ];
                  currentController.dispose();
                  pinController.dispose();
                  confirmController.dispose();
                  Navigator.of(dialogContext).pop(values);
                }
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  void _lockNow() {
    context.read<AppState>().lock();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final pinEnabled = appState.pinEnabled;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
          children: <Widget>[
            Text(
              'Paramètres',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 3),
            Text(
              'Sécurité, données et préférences.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 16),
            AppCard(
              color: AppColors.ink,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      pinEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
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
                          pinEnabled
                              ? 'Wanma est protégé'
                              : 'Wanma est sans code',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pinEnabled
                              ? 'Le code est requis à l’ouverture et après '
                                    '15 secondes en arrière-plan.'
                              : 'Ajoutez un code pour protéger l’accès au '
                                    'stock et aux clients.',
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
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Sécurité'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  if (!pinEnabled)
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      color: AppColors.primary,
                      background: AppColors.primaryLight,
                      title: 'Activer le verrouillage',
                      subtitle: 'Code PIN à 4 chiffres, stocké de façon salée.',
                      onTap: _busy ? null : _enablePin,
                    )
                  else ...<Widget>[
                    _SettingsTile(
                      icon: Icons.password_rounded,
                      color: AppColors.primary,
                      background: AppColors.primaryLight,
                      title: 'Changer le code PIN',
                      subtitle: 'Votre code actuel est demandé.',
                      onTap: _busy ? null : _changePin,
                    ),
                    const Divider(height: 1, indent: 62),
                    _SettingsTile(
                      icon: Icons.lock_clock_outlined,
                      color: AppColors.violet,
                      background: AppColors.violetLight,
                      title: 'Verrouiller maintenant',
                      subtitle: 'L’écran de déverrouillage s’affiche aussitôt.',
                      onTap: _lockNow,
                    ),
                    const Divider(height: 1, indent: 62),
                    _SettingsTile(
                      icon: Icons.lock_open_rounded,
                      color: AppColors.danger,
                      background: AppColors.dangerLight,
                      title: 'Désactiver le code PIN',
                      subtitle: 'Le téléphone ne sera plus verrouillé.',
                      onTap: _busy ? null : _disablePin,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Données locales'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _SettingsTile(
                    icon: Icons.backup_outlined,
                    color: AppColors.success,
                    background: AppColors.successLight,
                    title: 'Sauvegarde et restauration',
                    subtitle:
                        '${appState.products.length} produits · '
                        '${appState.clients.length} clients · '
                        '${appState.movements.length} mouvements',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BackupRestoreScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 62),
                  _SettingsTile(
                    icon: Icons.ios_share_rounded,
                    color: AppColors.info,
                    background: AppColors.infoLight,
                    title: 'Exporter les données',
                    subtitle: 'Produits, clients ou mouvements en CSV / Excel.',
                    onTap: () => showDataExportSheet(context),
                  ),
                  const Divider(height: 1, indent: 62),
                  const _SettingsTile(
                    icon: Icons.storage_rounded,
                    color: AppColors.textSecondary,
                    background: AppColors.background,
                    title: 'Stockage : SQLite local',
                    subtitle: 'Aucun compte, aucun serveur, aucun accès Internet requis.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Application'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _SettingsTile(
                    icon: Icons.menu_book_outlined,
                    color: AppColors.warning,
                    background: AppColors.warningLight,
                    title: 'Guide d’utilisation',
                    subtitle:
                        'Produits, clients, entrées, sorties et rapports.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HelpScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 62),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    color: AppColors.primary,
                    background: AppColors.primaryLight,
                    title: 'À propos de Wanma',
                    subtitle:
                        'Version 1.0.0 · Français · ${AppConstants.currency}',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: '1.0.0',
                        applicationIcon: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.warehouse_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                        children: const <Widget>[
                          Text(
                            'Gestion de stock et de clients, entièrement hors '
                            'ligne. Vos données restent sur votre téléphone.',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const InfoBanner(
              text:
                  'Wanma n’utilise aucune connexion réseau. Les exports et '
                  'sauvegardes sont créés localement ; leur partage éventuel '
                  'passe uniquement par le menu Android.',
              icon: Icons.wifi_off_rounded,
              color: AppColors.cobalt,
              backgroundColor: AppColors.cobaltSoft,
            ),
            const SizedBox(height: 22),
            const Text(
              'Wanma 1.0.0 · Fait pour les commerces de proximité',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      obscuringCharacter: '●',
      keyboardType: TextInputType.number,
      maxLength: 4,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        letterSpacing: 8,
      ),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      validator:
          validator ??
          (value) {
            if (value == null || !RegExp(r'^\d{4}$').hasMatch(value)) {
              return 'Saisissez 4 chiffres.';
            }
            return null;
          },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
