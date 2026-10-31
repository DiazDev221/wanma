import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/movement_grouping.dart';
import '../../../data/models/product.dart';
import '../../../data/models/report_data.dart';
import '../../../services/analytics_service.dart';
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

enum _ProductRange { today, week, month, custom }

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  _ProductRange _range = _ProductRange.month;
  ReportPeriod _period = AnalyticsService.periodForMonth();

  int get _productId => widget.productId;

  void _selectRange(_ProductRange range) {
    if (range == _ProductRange.custom) {
      _pickCustomPeriod();
      return;
    }
    setState(() {
      _range = range;
      switch (range) {
        case _ProductRange.today:
          _period = AnalyticsService.periodForToday();
        case _ProductRange.week:
          _period = AnalyticsService.periodForWeek();
        case _ProductRange.month:
          _period = AnalyticsService.periodForMonth();
        case _ProductRange.custom:
          break;
      }
    });
  }

  Future<void> _pickCustomPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: _range == _ProductRange.custom
            ? _period.start
            : DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(const Duration(days: 6)),
        end: _range == _ProductRange.custom
            ? _period.end.subtract(const Duration(days: 1))
            : DateTime(now.year, now.month, now.day),
      ),
      helpText: 'Choisir la période d’encaissement',
      saveText: 'Afficher',
      cancelText: 'Annuler',
    );
    if (range == null || !mounted) return;
    setState(() {
      _range = _ProductRange.custom;
      _period = AnalyticsService.customPeriod(range.start, range.end);
    });
  }

  String get _periodCaption {
    if (_range == _ProductRange.custom) {
      final lastDay = _period.end.subtract(const Duration(days: 1));
      return 'du ${AppFormatters.date(_period.start)} au '
          '${AppFormatters.date(lastDay)}';
    }
    return _period.label.toLowerCase();
  }

  String _creditCaption(ProductSalesStats stats) {
    if (stats.creditCount == 0) return 'Aucune vente à crédit';
    final sales =
        '${stats.creditCount} vente${stats.creditCount > 1 ? 's' : ''}';
    if (stats.unpaidCreditAmount == 0) return '$sales · toutes réglées';
    return '$sales · ${AppFormatters.money(stats.unpaidCreditAmount)} '
        'à recouvrer';
  }

  Future<void> _delete(BuildContext context, Product product) async {
    final appState = context.read<AppState>();
    if (appState.movementsForProduct(_productId).isNotEmpty) {
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
      await appState.deleteProduct(_productId);
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
    final product = appState.productById(_productId);
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
    final movements = appState.movementsForProduct(_productId);
    final recentMovements = movements.take(4).toList(growable: false);
    final recentGroups = groupMovementsByDay(recentMovements);
    final canDelete = movements.isEmpty;
    final salesStats = appState.productSalesStats(_productId, _period);

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
                const SectionHeader(
                  title: 'Encaissements et crédits',
                  subtitle:
                      'Suivez l’argent reçu et les crédits liés à ce produit.',
                ),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: <Widget>[
                          _ProductRangeChip(
                            label: 'Aujourd’hui',
                            icon: Icons.today_rounded,
                            selected: _range == _ProductRange.today,
                            onTap: () => _selectRange(_ProductRange.today),
                          ),
                          _ProductRangeChip(
                            label: 'Semaine',
                            icon: Icons.date_range_rounded,
                            selected: _range == _ProductRange.week,
                            onTap: () => _selectRange(_ProductRange.week),
                          ),
                          _ProductRangeChip(
                            label: 'Mois',
                            icon: Icons.calendar_month_rounded,
                            selected: _range == _ProductRange.month,
                            onTap: () => _selectRange(_ProductRange.month),
                          ),
                          _ProductRangeChip(
                            label: 'Période',
                            icon: Icons.edit_calendar_rounded,
                            selected: _range == _ProductRange.custom,
                            onTap: () => _selectRange(_ProductRange.custom),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.mintSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.payments_outlined,
                                  size: 16,
                                  color: AppColors.mint,
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: MicroLabel(
                                    'Montant encaissé',
                                    color: AppColors.mint,
                                  ),
                                ),
                                Text(
                                  _periodCaption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.mint.withValues(
                                      alpha: 0.75,
                                    ),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            MoneyDisplay(
                              amount: salesStats.collectedAmount,
                              color: AppColors.mint,
                              unitColor: AppColors.mint.withValues(alpha: 0.55),
                              amountSize: 30,
                              unitSize: 9,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${salesStats.collectionCount} encaissement'
                              '${salesStats.collectionCount > 1 ? 's' : ''} · '
                              '${salesStats.saleCount} sortie'
                              '${salesStats.saleCount > 1 ? 's' : ''} sur la '
                              'période',
                              style: TextStyle(
                                color: AppColors.mint.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(
                              child: _ProductMetricCard(
                                label: 'Crédits de la période',
                                value: AppFormatters.money(
                                  salesStats.creditAmount,
                                ),
                                caption: _creditCaption(salesStats),
                                icon: Icons.schedule_rounded,
                                color: AppColors.amberDark,
                                background: AppColors.amberSoft,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ProductMetricCard(
                                label: 'Total des crédits',
                                value: AppFormatters.money(
                                  salesStats.outstandingCreditAmount,
                                ),
                                caption:
                                    'Toutes périodes · '
                                    '${salesStats.outstandingCreditCount} sortie'
                                    '${salesStats.outstandingCreditCount > 1 ? 's' : ''}',
                                icon: Icons.error_outline_rounded,
                                color: AppColors.coral,
                                background: AppColors.coralSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (salesStats.outstandingCreditCount > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => EntityMovementsScreen(
                                  title: product.name,
                                  productId: _productId,
                                  creditOnly: true,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.amberDark,
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                          ),
                          label: const Text(
                            'Voir les crédits en cours de ce produit',
                            style: TextStyle(fontSize: 10.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amberSoft.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: AppColors.amberDark,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Les crédits remboursés sont comptés le jour '
                                'du règlement.',
                                style: TextStyle(
                                  color: AppColors.amberDark.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 9.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                                productId: _productId,
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

class _ProductRangeChip extends StatelessWidget {
  const _ProductRangeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.cobalt : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.cobalt : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductMetricCard extends StatelessWidget {
  const _ProductMetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 9,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
