import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/movement_grouping.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/movement_date_header.dart';
import '../../widgets/movement_tile.dart';
import 'movement_detail_screen.dart';

/// Historique filtré sur un produit ou un client.
class EntityMovementsScreen extends StatelessWidget {
  const EntityMovementsScreen({
    super.key,
    required this.title,
    this.productId,
    this.clientId,
    this.creditOnly = false,
  }) : assert(
         creditOnly || ((productId != null) ^ (clientId != null)),
         'Indiquez soit un produit, soit un client.',
       );

  final String title;
  final int? productId;
  final int? clientId;

  /// N'affiche que les sorties à crédit encore dues.
  final bool creditOnly;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final movements = appState.filterMovements(
      productId: productId,
      clientId: clientId,
      unpaidCreditOnly: creditOnly,
    );
    final dayGroups = groupMovementsByDay(movements);
    final isClient = clientId != null;
    final isGlobalCreditView = creditOnly && !isClient && productId == null;
    final active = movements.where((movement) => movement.isActive).toList();
    final totalAmount = active.fold<int>(
      0,
      (sum, movement) => sum + (movement.isExit ? movement.totalAmount : 0),
    );
    final totalEntries = active
        .where((movement) => movement.isEntry)
        .fold<double>(0, (sum, movement) => sum + movement.quantity);
    final totalExits = active
        .where((movement) => movement.isExit)
        .fold<double>(0, (sum, movement) => sum + movement.quantity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isGlobalCreditView
              ? 'Crédits à recouvrer'
              : isClient
              ? creditOnly
                    ? 'Crédits du client'
                    : 'Sorties du client'
              : 'Historique produit',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: appState.refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
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
                  MicroLabel(
                    isGlobalCreditView
                        ? 'CRÉDITS'
                        : isClient
                        ? 'CLIENT'
                        : 'PRODUIT',
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    creditOnly
                        ? '${movements.length} sortie'
                              '${movements.length > 1 ? 's' : ''} à recouvrer'
                        : '${movements.length} opération'
                              '${movements.length > 1 ? 's' : ''} · '
                              '${active.length} validée'
                              '${active.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      if (!isClient && !creditOnly) ...<Widget>[
                        Expanded(
                          child: _SummaryMetric(
                            label: 'Entrées',
                            value: AppFormatters.quantity(totalEntries),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: _SummaryMetric(
                          label: creditOnly
                              ? 'Quantité à crédit'
                              : isClient
                              ? 'Quantité sortie'
                              : 'Sorties',
                          value: AppFormatters.quantity(totalExits),
                        ),
                      ),
                      if (isClient || creditOnly) ...<Widget>[
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _SummaryMetric(
                            label: creditOnly
                                ? 'Montant à recouvrer'
                                : 'Montant validé',
                            value: AppFormatters.money(totalAmount),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionHeader(
              title: creditOnly ? 'Sorties à crédit' : 'Détail des opérations',
            ),
            if (movements.isEmpty)
              AppCard(
                child: EmptyState(
                  icon: creditOnly
                      ? Icons.check_circle_outline_rounded
                      : Icons.swap_vert_rounded,
                  title: creditOnly
                      ? 'Aucun crédit en cours'
                      : 'Aucune opération',
                  message: creditOnly
                      ? 'Toutes les sorties à crédit ont été remboursées.'
                      : 'Aucun mouvement à afficher pour le moment.',
                  compact: true,
                ),
              )
            else
              for (
                var groupIndex = 0;
                groupIndex < dayGroups.length;
                groupIndex++
              ) ...<Widget>[
                MovementDateHeader(
                  date: dayGroups[groupIndex].date,
                  count: dayGroups[groupIndex].movements.length,
                  topPadding: groupIndex == 0 ? 0 : 12,
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  child: Column(
                    children: <Widget>[
                      for (
                        var i = 0;
                        i < dayGroups[groupIndex].movements.length;
                        i++
                      ) ...<Widget>[
                        MovementTile(
                          movement: dayGroups[groupIndex].movements[i],
                          onTap: () {
                            final id = dayGroups[groupIndex].movements[i].id;
                            if (id == null) return;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    MovementDetailScreen(movementId: id),
                              ),
                            );
                          },
                        ),
                        if (i < dayGroups[groupIndex].movements.length - 1)
                          const Divider(height: 1, indent: 50),
                      ],
                    ],
                  ),
                ),
                if (groupIndex < dayGroups.length - 1)
                  const SizedBox(height: 4),
              ],
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
