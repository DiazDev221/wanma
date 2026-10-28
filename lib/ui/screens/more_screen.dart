import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/app_state.dart';
import '../widgets/app_card.dart';
import '../widgets/data_export_sheet.dart';
import '../widgets/form_sections.dart';
import '../widgets/wanma_logo.dart';
import 'help_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/backup_restore_screen.dart';
import 'settings/settings_screen.dart';

/// Cinquième onglet : outils, rapports, sauvegarde et paramètres.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final stats = appState.dashboardStats;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.screenPadding,
            12,
            AppTokens.screenPadding,
            28,
          ),
          children: <Widget>[
            Text(
              'Outils',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 3),
            Text(
              'Les outils de votre boutique.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 16),
            _ShopCard(
              productCount: stats.productCount,
              clientCount: stats.clientCount,
              stockValue: stats.stockValue,
              movementCount: appState.movements.length,
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Outils du magasin'),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _ToolTile(
                      icon: Icons.insights_rounded,
                      title: 'Rapports',
                      subtitle: 'Statistiques et exports',
                      color: AppColors.cobalt,
                      background: AppColors.cobaltSoft,
                      onTap: () => _open(context, const ReportsScreen()),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _ToolTile(
                      icon: Icons.backup_outlined,
                      title: 'Sauvegarde',
                      subtitle: 'Créer ou restaurer',
                      color: AppColors.mint,
                      background: AppColors.mintSoft,
                      onTap: () => _open(context, const BackupRestoreScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _ToolTile(
                      icon: Icons.settings_outlined,
                      title: 'Paramètres',
                      subtitle: 'Sécurité et données',
                      color: AppColors.violet,
                      background: AppColors.violetSoft,
                      onTap: () => _open(context, const SettingsScreen()),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _ToolTile(
                      icon: Icons.ios_share_rounded,
                      title: 'Exporter',
                      subtitle: 'CSV et Excel',
                      color: AppColors.amberDark,
                      background: AppColors.amberSoft,
                      onTap: () => showDataExportSheet(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Aide et application'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _MenuRow(
                    icon: Icons.menu_book_outlined,
                    title: 'Guide d’utilisation',
                    subtitle: 'Apprendre les gestes essentiels',
                    color: AppColors.cobalt,
                    background: AppColors.cobaltSoft,
                    onTap: () => _open(context, const HelpScreen()),
                  ),
                  const Divider(height: 1, indent: 60),
                  if (appState.pinEnabled) ...<Widget>[
                    _MenuRow(
                      icon: Icons.lock_clock_outlined,
                      title: 'Verrouiller maintenant',
                      subtitle: 'Retourner à l’écran du code PIN',
                      color: AppColors.violet,
                      background: AppColors.violetSoft,
                      onTap: appState.lock,
                    ),
                    const Divider(height: 1, indent: 60),
                  ],
                  _MenuRow(
                    icon: Icons.info_outline_rounded,
                    title: 'À propos de Wanma',
                    subtitle: 'Version 1.0.0 · Français · FCFA',
                    color: AppColors.muted,
                    background: AppColors.paper,
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: '1.0.0',
                        applicationIcon: const WanmaLogo(size: 48),
                        children: const <Widget>[
                          Text(
                            'Wanma est une application de gestion de stock et '
                            'de clients qui fonctionne sans Internet. Toutes '
                            'les données restent sur votre téléphone.',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.cobaltSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.storage_rounded,
                          size: 19,
                          color: AppColors.cobalt,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Base de données locale',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              '${appState.movements.length} mouvement'
                              '${appState.movements.length > 1 ? 's' : ''} '
                              'enregistré'
                              '${appState.movements.length > 1 ? 's' : ''}',
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
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.mint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const InfoBanner(
                    text:
                        'Aucune donnée n’est envoyée sur Internet. Pensez à '
                        'créer une sauvegarde régulière dans un endroit sûr.',
                    icon: Icons.verified_user_outlined,
                    color: AppColors.mint,
                    backgroundColor: AppColors.mintSoft,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Wanma 1.0.0 · gestion de stock hors ligne',
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

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.productCount,
    required this.clientCount,
    required this.stockValue,
    required this.movementCount,
  });

  final int productCount;
  final int clientCount;
  final int stockValue;
  final int movementCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.ink, Color(0xFF1C2C47)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.heroRadius),
        boxShadow: const <BoxShadow>[AppTokens.floatingShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const WanmaLogo(size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const MicroLabel(
                      'Votre boutique',
                      color: Color(0x99FFFFFF),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: Colors.white, fontSize: 19),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.wifi_off_rounded,
                      color: AppColors.amber,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Hors ligne',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
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
              Expanded(
                child: _ShopStat(value: '$productCount', label: 'Produits'),
              ),
              _ShopDivider(),
              Expanded(
                child: _ShopStat(value: '$clientCount', label: 'Clients'),
              ),
              _ShopDivider(),
              Expanded(
                child: _ShopStat(
                  value: AppFormatters.money(stockValue),
                  label: 'Valeur du stock',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Icon(
                Icons.shield_outlined,
                size: 13,
                color: AppColors.amber,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '$movementCount opération'
                  '${movementCount > 1 ? 's' : ''} conservée'
                  '${movementCount > 1 ? 's' : ''} sur cet appareil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopStat extends StatelessWidget {
  const _ShopStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 2),
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
    );
  }
}

class _ShopDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
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
                      fontSize: 10,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
