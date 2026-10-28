import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/movement_grouping.dart';
import '../../../data/models/product.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/avatars.dart';
import '../../widgets/badges.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/movement_date_header.dart';
import '../../widgets/movement_tile.dart';
import '../movements/entity_movements_screen.dart';
import '../movements/movement_detail_screen.dart';
import '../stock/stock_entry_screen.dart';
import '../stock/stock_exit_screen.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  Future<void> _delete(BuildContext context, Product product) async {
    final appState = context.read<AppState>();
    if (appState.movementsForProduct(productId).isNotEmpty) {
      AppFeedback.info(
        context,
        'Ce produit possède un historique de mouvements. Il ne peut pas être '
        'supprimé afin de préserver vos données.',
      );
      return;
    }
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Supprimer ce produit ?',
      message:
          'Le produit « ${product.name} » sera définitivement supprimé. '
          'Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await appState.deleteProduct(productId);
      if (!context.mounted) return;
      AppFeedback.success(context, 'Le produit a été supprimé.');
      Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) AppFeedback.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final product = appState.productById(productId);
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails du produit')),
        body: const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Produit introuvable',
          message: 'Ce produit a peut-être été supprimé.',
        ),
      );
    }
    final movements = appState.movementsForProduct(productId);
    final recentMovements = movements.take(4).toList(growable: false);
    final recentGroups = groupMovementsByDay(recentMovements);
    final canDelete = movements.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche produit'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Plus d’actions',
            onSelected: (value) {
              if (value == 'delete') _delete(context, product);
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.delete_outline_rounded,
                      color: canDelete ? AppColors.coral : AppColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Supprimer',
                      style: TextStyle(
                        color: canDelete ? AppColors.coral : AppColors.muted,
                      ),
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
                        builder: (_) =>
                            StockEntryScreen(initialProduct: product),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.south_rounded,
                    size: 18,
                    color: AppColors.mint,
                  ),
                  label: const Text('Entrée'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            StockExitScreen(initialProduct: product),
                      ),
                    );
                  },
                  icon: const Icon(Icons.north_rounded, size: 18),
                  label: const Text('Sortie'),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ProductAvatar(name: product.name, size: 66),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontSize: 20),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  product.reference?.isNotEmpty == true
                                      ? 'Réf. ${product.reference}'
                                      : 'Sans référence',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                ),
                                const SizedBox(height: 9),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: <Widget>[
                                    StockBadge(
                                      quantity: product.quantity,
                                      unit: product.unit,
                                      lowStock: product.isLowStock,
                                    ),
                                    if (product.isLowStock)
                                      LowStockBadge(product: product),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cobaltSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.sell_outlined,
                              size: 19,
                              color: AppColors.cobalt,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                AppFormatters.money(product.unitPrice),
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 22,
                                      color: AppColors.cobalt,
                                    ),
                              ),
                            ),
                            Text(
                              'par ${product.unit.toLowerCase()}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProductFormScreen(product: product),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Modifier'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _delete(context, product),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: canDelete
                              ? AppColors.coral
                              : AppColors.muted,
                          side: BorderSide(
                            color: canDelete
                                ? AppColors.coral.withValues(alpha: 0.35)
                                : AppColors.line,
                          ),
                        ),
                        icon: Icon(
                          canDelete
                              ? Icons.delete_outline_rounded
                              : Icons.lock_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Informations'),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: <Widget>[
                      InfoRow(
                        label: 'Quantité disponible',
                        value:
                            '${AppFormatters.quantity(product.quantity)} ${product.unit.toLowerCase()}',
                        icon: Icons.inventory_rounded,
                        valueColor: product.isLowStock
                            ? AppColors.amberDark
                            : AppColors.ink,
                      ),
                      InfoRow(
                        label: 'Seuil d’alerte',
                        value:
                            '${AppFormatters.quantity(product.lowStockThreshold)} ${product.unit.toLowerCase()}',
                        icon: Icons.notifications_outlined,
                      ),
                      InfoRow(
                        label: 'Valeur du stock',
                        value: AppFormatters.money(product.stockValue),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      InfoRow(
                        label: 'Unité',
                        value: product.unit,
                        icon: Icons.straighten_rounded,
                      ),
                      InfoRow(
                        label: 'Date de création',
                        value: AppFormatters.dateTime(product.createdAt),
                        icon: Icons.calendar_month_outlined,
                      ),
                      InfoRow(
                        label: 'Dernière modification',
                        value: AppFormatters.dateTime(product.updatedAt),
                        icon: Icons.update_rounded,
                      ),
                      InfoRow(
                        label: 'Mouvements',
                        value: '${movements.length}',
                        icon: Icons.swap_vert_rounded,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (product.description != null &&
                    product.description!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  const SectionHeader(title: 'Description'),
                  AppCard(
                    child: Text(
                      product.description!,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(height: 1.5, color: AppColors.muted),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SectionHeader(
                  title: 'Mouvements récents',
                  actionLabel: movements.isEmpty ? null : 'Voir tout',
                  onAction: movements.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EntityMovementsScreen(
                                title: product.name,
                                productId: productId,
                              ),
                            ),
                          );
                        },
                ),
                if (recentMovements.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.swap_vert_rounded,
                      title: 'Aucun mouvement',
                      message: 'Les entrées et sorties de ce produit apparaîtront ici.',
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
