import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/movement_grouping.dart';
import '../../../data/models/product.dart';
import '../../../state/app_state.dart';
import '../widgets/app_card.dart';
import '../widgets/badges.dart';
import '../widgets/empty_state.dart';
import '../widgets/movement_date_header.dart';
import '../widgets/movement_tile.dart';
import '../widgets/wanma_logo.dart';
import 'movements/entity_movements_screen.dart';
import 'movements/movement_detail_screen.dart';
import 'products/low_stock_screen.dart';
import 'products/product_detail_screen.dart';
import 'reports/reports_screen.dart';
import 'stock/stock_entry_screen.dart';
import 'stock/stock_exit_screen.dart';

/// Tableau de bord principal de Wanma.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final stats = appState.dashboardStats;
    final recent = stats.recentMovements.take(3).toList(growable: false);
    final recentGroups = groupMovementsByDay(recent);
    final lowStock = stats.lowStockProducts;
    final visibleLowStock = lowStock.take(3).toList(growable: false);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: appState.refreshData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTokens.screenPadding,
              12,
              AppTokens.screenPadding,
              28,
            ),
            children: <Widget>[
              _DashboardHeader(
                lowStockCount: stats.lowStockProducts.length,
                onAlerts: () => _open(context, const LowStockScreen()),
              ),
              const SizedBox(height: 18),
              Text(
                'Que voulez-vous faire ?',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontSize: 24, letterSpacing: -1.1),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  const _OnlineDot(),
                  const SizedBox(width: 5),
                  Text(
                    'Hors ligne',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mint,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '· ${AppFormatters.longDate(DateTime.now())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 10.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _EasyActionCard(
                      icon: Icons.shopping_bag_rounded,
                      title: 'Vendre',
                      subtitle: 'Retirer un article',
                      color: AppColors.coral,
                      background: AppColors.coralSoft,
                      onTap: () => _open(context, const StockExitScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EasyActionCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Réception',
                      subtitle: 'Ajouter au stock',
                      color: AppColors.mint,
                      background: AppColors.mintSoft,
                      onTap: () => _open(context, const StockEntryScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _EasyActionCard(
                      icon: Icons.inventory_rounded,
                      title: 'Articles',
                      subtitle: 'Voir mes produits',
                      color: AppColors.cobalt,
                      background: AppColors.cobaltSoft,
                      onTap: () => onSelectTab(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EasyActionCard(
                      icon: Icons.people_alt_rounded,
                      title: 'Clients',
                      subtitle: 'Voir mes clients',
                      color: AppColors.violet,
                      background: AppColors.violetSoft,
                      onTap: () => onSelectTab(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _HeroCard(
                stockValue: stats.stockValue,
                productCount: stats.productCount,
                onReports: () => _open(context, const ReportsScreen()),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: EdgeInsets.zero,
                child: IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _KpiTile(
                          value: '${stats.productCount}',
                          label: 'Produits',
                          color: AppColors.cobalt,
                          onTap: () => onSelectTab(1),
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        indent: 12,
                        endIndent: 12,
                      ),
                      Expanded(
                        child: _KpiTile(
                          value: '${stats.clientCount}',
                          label: 'Clients',
                          color: AppColors.violet,
                          onTap: () => onSelectTab(2),
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        indent: 12,
                        endIndent: 12,
                      ),
                      Expanded(
                        child: _KpiTile(
                          value: '${stats.todayExitCount}',
                          label: 'Sorties',
                          color: AppColors.coral,
                          onTap: () => onSelectTab(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (stats.outstandingCreditCount > 0) ...<Widget>[
                const SizedBox(height: 12),
                AppCard(
                  color: AppColors.amberSoft,
                  borderColor: AppColors.amber.withValues(alpha: 0.35),
                  onTap: () => _open(
                    context,
                    const EntityMovementsScreen(
                      title: 'Crédits à recouvrer',
                      creditOnly: true,
                    ),
                  ),
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
                              'Crédits à recouvrer',
                              style: TextStyle(
                                color: AppColors.amberDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.money(
                                stats.outstandingCreditAmount,
                              ),
                              style: const TextStyle(
                                color: AppColors.amberDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              '${stats.outstandingCreditCount} sortie'
                              '${stats.outstandingCreditCount > 1 ? 's' : ''} '
                              'à crédit · Toucher pour voir',
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
              const SizedBox(height: 20),
              SectionHeader(
                title: 'À réapprovisionner',
                subtitle: lowStock.isEmpty
                    ? 'Tous vos produits sont bien approvisionnés.'
                    : '${lowStock.length} produit'
                          '${lowStock.length > 1 ? 's' : ''} sous le seuil d’alerte.',
                actionLabel: lowStock.isEmpty ? null : 'Voir tout',
                onAction: lowStock.isEmpty
                    ? null
                    : () => _open(context, const LowStockScreen()),
              ),
              if (lowStock.isEmpty)
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.mintSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppColors.mint,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          stats.productCount == 0
                              ? 'Ajoutez vos premiers produits pour suivre le stock.'
                              : 'Tous vos produits sont bien approvisionnés.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Column(
                    children: <Widget>[
                      for (
                        var index = 0;
                        index < visibleLowStock.length;
                        index++
                      ) ...<Widget>[
                        _LowStockRow(
                          product: visibleLowStock[index],
                          onTap: () => _open(
                            context,
                            visibleLowStock[index].id == null
                                ? const LowStockScreen()
                                : ProductDetailScreen(
                                    productId: visibleLowStock[index].id!,
                                  ),
                          ),
                        ),
                        if (index < visibleLowStock.length - 1)
                          const Divider(height: 1, indent: 50),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'Dernières opérations',
                actionLabel: recent.isEmpty ? null : 'Voir tout',
                onAction: recent.isEmpty ? null : () => onSelectTab(3),
              ),
              if (recent.isEmpty)
                AppCard(
                  child: EmptyState(
                    icon: Icons.swap_vert_rounded,
                    title: 'Aucune opération',
                    message:
                        'Vos premières entrées et sorties apparaîtront ici.',
                    actionLabel: appState.products.isEmpty
                        ? 'Créer un produit'
                        : null,
                    onAction: appState.products.isEmpty
                        ? () => onSelectTab(1)
                        : null,
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
                          var index = 0;
                          index < recentGroups[groupIndex].movements.length;
                          index++
                        ) ...<Widget>[
                          MovementTile(
                            movement: recentGroups[groupIndex].movements[index],
                            onTap:
                                recentGroups[groupIndex].movements[index].id ==
                                    null
                                ? null
                                : () => _open(
                                    context,
                                    MovementDetailScreen(
                                      movementId: recentGroups[groupIndex]
                                          .movements[index]
                                          .id!,
                                    ),
                                  ),
                          ),
                          if (index <
                              recentGroups[groupIndex].movements.length - 1)
                            const Divider(height: 1, indent: 50),
                        ],
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 14,
                    color: AppColors.mint,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Données enregistrées localement sur cet appareil.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _open(context, const ReportsScreen()),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                    child: const Text('Rapports'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grande action visuelle conçue pour être facile à repérer et à toucher.
class _EasyActionCard extends StatelessWidget {
  const _EasyActionCard({
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
    return Semantics(
      excludeSemantics: true,
      button: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 116),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
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

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.lowStockCount, required this.onAlerts});

  final int lowStockCount;
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const WanmaLogo(size: 34),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppConstants.appName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: AppColors.ink,
                ),
              ),
              Text(
                'Votre magasin, mieux géré',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 8.5, letterSpacing: 0.1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            _RoundIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Alertes de stock',
              onTap: onAlerts,
            ),
            if (lowStockCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.stockValue,
    required this.productCount,
    required this.onReports,
  });

  final int stockValue;
  final int productCount;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.ink, Color(0xFF1C2C47)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.heroRadius),
        boxShadow: const <BoxShadow>[AppTokens.floatingShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.heroRadius),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -36,
              top: -48,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.amber.withValues(alpha: 0.22),
                      AppColors.amber.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: MicroLabel(
                          'Valeur du stock',
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                      Material(
                        color: Colors.white.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: onReports,
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.insights_rounded,
                              color: AppColors.amber,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: MoneyDisplay(
                          amount: stockValue,
                          color: Colors.white,
                          unitColor: Colors.white.withValues(alpha: 0.55),
                          amountSize: 31,
                          unitSize: 9,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: _Sparkline(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$productCount produit${productCount > 1 ? 's' : ''} '
                    'suivi${productCount > 1 ? 's' : ''} · prix actuels',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
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

class _Sparkline extends StatelessWidget {
  const _Sparkline();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 30,
      child: CustomPaint(painter: _SparklinePainter()),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const heights = <double>[0.32, 0.48, 0.36, 0.62, 0.5, 0.74, 0.58, 0.9];
    final barWidth = size.width / (heights.length * 1.7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < heights.length; index++) {
      final height = size.height * heights[index];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          index * barWidth * 1.7,
          size.height - height,
          barWidth,
          height,
        ),
        Radius.circular(barWidth / 2),
      );
      paint.color = AppColors.amber.withValues(
        alpha: 0.25 + (index / heights.length) * 0.65,
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.7,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.amberDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seuil d’alerte · '
                    '${AppFormatters.quantity(product.lowStockThreshold)} '
                    '${product.unit.toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StockBadge(
              quantity: product.quantity,
              unit: product.unit,
              lowStock: true,
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              boxShadow: const <BoxShadow>[AppTokens.cardShadow],
            ),
            child: Icon(icon, size: 19, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.mint,
        shape: BoxShape.circle,
      ),
    );
  }
}
