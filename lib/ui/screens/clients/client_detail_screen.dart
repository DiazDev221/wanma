import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/movement_grouping.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/avatars.dart';
import '../../widgets/client_call_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/movement_date_header.dart';
import '../../widgets/movement_tile.dart';
import '../movements/entity_movements_screen.dart';
import '../movements/movement_detail_screen.dart';
import '../stock/stock_exit_screen.dart';
import 'client_form_screen.dart';

class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  Future<void> _delete(BuildContext context) async {
    final appState = context.read<AppState>();
    if (appState.movementsForClient(clientId).isNotEmpty) {
      AppFeedback.info(
        context,
        'Ce client possède un historique de sorties et ne peut pas être '
        'supprimé afin de préserver vos données.',
      );
      return;
    }
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Supprimer ce client ?',
      message:
          'La fiche de ce client sera définitivement supprimée. '
          'Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await appState.deleteClient(clientId);
      if (!context.mounted) return;
      AppFeedback.success(context, 'Le client a été supprimé.');
      Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) AppFeedback.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final client = appState.clientById(clientId);
    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fiche client')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Client introuvable',
          message: 'Ce client a peut-être été supprimé.',
        ),
      );
    }
    final movements = appState.movementsForClient(clientId);
    final activeMovements = movements
        .where((movement) => movement.isActive)
        .toList();
    final totalAmount = activeMovements.fold<int>(
      0,
      (sum, movement) => sum + movement.totalAmount,
    );
    final pendingCredits = movements
        .where((movement) => movement.isCreditPending)
        .toList(growable: false);
    final creditAmount = pendingCredits.fold<int>(
      0,
      (sum, movement) => sum + movement.totalAmount,
    );
    final recent = movements.take(5).toList(growable: false);
    final recentGroups = groupMovementsByDay(recent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche client'),
        actions: <Widget>[
          ClientCallButton(phone: client.phone, clientName: client.fullName),
          PopupMenuButton<String>(
            tooltip: 'Plus d’actions',
            onSelected: (value) {
              if (value == 'delete') _delete(context);
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.coral,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Supprimer',
                      style: TextStyle(color: AppColors.coral),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x140E1A2B),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ClientFormScreen(client: client),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StockExitScreen(initialClient: client),
                      ),
                    );
                  },
                  icon: const Icon(Icons.north_rounded, size: 18),
                  label: const Text('Nouvelle sortie'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppCard(
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          ClientAvatar(
                            firstName: client.firstName,
                            lastName: client.lastName,
                            size: 64,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  client.fullName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontSize: 20),
                                ),
                                const SizedBox(height: 5),
                                ClientCallButton(
                                  phone: client.phone,
                                  clientName: client.fullName,
                                  showNumber: true,
                                  phoneStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                  iconSize: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _MiniStat(
                              label: 'Sorties',
                              value: '${activeMovements.length}',
                              color: AppColors.cobalt,
                              background: AppColors.cobaltSoft,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _MiniStat(
                              label: 'Montant total',
                              value: AppFormatters.money(totalAmount),
                              color: AppColors.mint,
                              background: AppColors.mintSoft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (creditAmount > 0) ...<Widget>[
                  const SizedBox(height: 14),
                  AppCard(
                    color: AppColors.amberSoft,
                    borderColor: AppColors.amber.withValues(alpha: 0.35),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EntityMovementsScreen(
                            title: client.fullName,
                            clientId: clientId,
                            creditOnly: true,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.amberDark,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Crédit en cours',
                                style: TextStyle(
                                  color: AppColors.amberDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppFormatters.money(creditAmount),
                                style: const TextStyle(
                                  color: AppColors.amberDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                '${pendingCredits.length} sortie'
                                '${pendingCredits.length > 1 ? 's' : ''} à '
                                'recouvrer · Toucher pour voir',
                                style: TextStyle(
                                  color: AppColors.amberDark.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.amberDark,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const SectionHeader(title: 'Coordonnées'),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: <Widget>[
                      InfoRow(
                        label: 'Prénom',
                        value: client.firstName,
                        icon: Icons.person_outline_rounded,
                      ),
                      InfoRow(
                        label: 'Nom',
                        value: client.lastName,
                        icon: Icons.person_outline_rounded,
                      ),
                      InfoRow(
                        label: 'Téléphone',
                        value: client.phone,
                        icon: Icons.phone_outlined,
                        onTap: () => callClient(
                          context,
                          phone: client.phone,
                          clientName: client.fullName,
                        ),
                        trailing: const Icon(
                          Icons.phone_in_talk_outlined,
                          size: 17,
                          color: AppColors.cobalt,
                        ),
                      ),
                      InfoRow(
                        label: 'Enregistré le',
                        value: AppFormatters.dateTime(client.createdAt),
                        icon: Icons.calendar_month_outlined,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  title: 'Historique des sorties',
                  subtitle: movements.isEmpty
                      ? null
                      : '${movements.length} opération${movements.length > 1 ? 's' : ''}',
                  actionLabel: movements.isEmpty ? null : 'Voir tout',
                  onAction: movements.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EntityMovementsScreen(
                                title: client.fullName,
                                clientId: clientId,
                              ),
                            ),
                          );
                        },
                ),
                if (recent.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Aucune sortie',
                      message:
                          'Les produits remis à ce client apparaîtront ici.',
                      compact: true,
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    child: Column(
                      children: <Widget>[
                        for (
                          var groupIndex = 0;
                          groupIndex < recentGroups.length;
                          groupIndex++
                        ) ...<Widget>[
                          MovementDateHeader(
                            date: recentGroups[groupIndex].date,
                            count: recentGroups[groupIndex].movements.length,
                            topPadding: groupIndex == 0 ? 4 : 10,
                          ),
                          for (
                            var i = 0;
                            i < recentGroups[groupIndex].movements.length;
                            i++
                          ) ...<Widget>[
                            MovementTile(
                              movement: recentGroups[groupIndex].movements[i],
                              compact: true,
                              onTap: () {
                                final id =
                                    recentGroups[groupIndex].movements[i].id;
                                if (id == null) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        MovementDetailScreen(movementId: id),
                                  ),
                                );
                              },
                            ),
                            if (i <
                                recentGroups[groupIndex].movements.length - 1)
                              const Divider(height: 1, indent: 50),
                          ],
                        ],
                      ],
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
