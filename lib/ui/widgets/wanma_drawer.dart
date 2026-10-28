import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../state/app_state.dart';
import '../screens/help_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/backup_restore_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'data_export_sheet.dart';
import 'wanma_logo.dart';

/// Menu latéral de l'application.
class WanmaDrawer extends StatelessWidget {
  const WanmaDrawer({super.key});

  void _push(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 22,
                20,
                20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const WanmaWordmark(logoSize: 42),
                  const SizedBox(height: 12),
                  Text(
                    AppConstants.appTagline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _DrawerCount(
                            value: '${appState.products.length}',
                            label: 'produits',
                          ),
                        ),
                        Expanded(
                          child: _DrawerCount(
                            value: '${appState.clients.length}',
                            label: 'clients',
                          ),
                        ),
                        Expanded(
                          child: _DrawerCount(
                            value: '${appState.movements.length}',
                            label: 'mouvements',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
                children: <Widget>[
                  _DrawerTile(
                    icon: Icons.dashboard_outlined,
                    label: 'Tableau de bord',
                    selected: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _DrawerTile(
                    icon: Icons.insights_rounded,
                    label: 'Rapports et statistiques',
                    onTap: () => _push(context, const ReportsScreen()),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 16, 12, 6),
                    child: Text(
                      'DONNÉES',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  _DrawerTile(
                    icon: Icons.backup_outlined,
                    label: 'Sauvegarde et restauration',
                    onTap: () => _push(context, const BackupRestoreScreen()),
                  ),
                  _DrawerTile(
                    icon: Icons.ios_share_rounded,
                    label: 'Exporter les données',
                    onTap: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (navigator.mounted) {
                          showDataExportSheet(navigator.context);
                        }
                      });
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 16, 12, 6),
                    child: Text(
                      'APPLICATION',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'Paramètres',
                    onTap: () => _push(context, const SettingsScreen()),
                  ),
                  _DrawerTile(
                    icon: Icons.menu_book_outlined,
                    label: 'Guide d’utilisation',
                    onTap: () => _push(context, const HelpScreen()),
                  ),
                  if (appState.pinEnabled)
                    _DrawerTile(
                      icon: Icons.lock_clock_outlined,
                      label: 'Verrouiller maintenant',
                      onTap: () {
                        Navigator.of(context).pop();
                        appState.lock();
                      },
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 15,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Fonctionne hors ligne',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerCount extends StatelessWidget {
  const _DrawerCount({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
