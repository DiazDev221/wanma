import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/avatars.dart';
import '../../widgets/badges.dart';
import '../../widgets/empty_state.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  ProductSort _sort = ProductSort.name;
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSort() async {
    final selected = await showModalBottomSheet<ProductSort>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Trier les produits',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                RadioGroup<ProductSort>(
                  groupValue: _sort,
                  onChanged: (value) {
                    if (value != null) Navigator.of(context).pop(value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final sort in ProductSort.values)
                        RadioListTile<ProductSort>(
                          value: sort,
                          title: Text(sort.label),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _sort = selected);
    }
  }

  void _openCreate() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProductFormScreen()));
  }

  void _openDetails(Product product) {
    if (product.id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(productId: product.id!),
      ),
    );
  }

  void _showAll() {
    setState(() {
      _lowStockOnly = false;
      _sort = ProductSort.name;
    });
  }

  void _showRecent() {
    setState(() {
      _lowStockOnly = false;
      _sort = ProductSort.recent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final products = appState.searchProducts(
      query: _query,
      sort: _sort,
      lowStockOnly: _lowStockOnly,
    );
    final hasAnyProducts = appState.products.isNotEmpty;
    final recentSelected = !_lowStockOnly && _sort == ProductSort.recent;
    final allSelected = !_lowStockOnly && !recentSelected;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.screenPadding,
                12,
                AppTokens.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                'Produits',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontSize: 28),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cobaltSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${appState.products.length}',
                                style: const TextStyle(
                                  color: AppColors.cobalt,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AddButton(onTap: _openCreate),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Votre catalogue, toujours à jour.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  AppSearchField(
                    controller: _searchController,
                    hintText: 'Rechercher un produit...',
                    onChanged: (value) => setState(() => _query = value),
                    trailing: _FilterButton(
                      active: _sort != ProductSort.name || _lowStockOnly,
                      onTap: _openSort,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              _FilterChip(
                                label: 'Tous',
                                selected: allSelected,
                                onTap: _showAll,
                              ),
                              const SizedBox(width: 7),
                              _FilterChip(
                                label: 'Stock faible',
                                selected: _lowStockOnly,
                                icon: Icons.warning_amber_rounded,
                                onTap: () =>
                                    setState(() => _lowStockOnly = true),
                              ),
                              const SizedBox(width: 7),
                              _FilterChip(
                                label: 'Récents',
                                selected: recentSelected,
                                onTap: _showRecent,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _openSort,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          textStyle: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(_sortShortLabel(_sort)),
                            const Icon(Icons.unfold_more_rounded, size: 13),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      const Expanded(child: MicroLabel('Tous les produits')),
                      Text(
                        '${products.length} article'
                        '${products.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: appState.refreshData,
                child: products.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.45,
                            child: EmptyState(
                              icon: _lowStockOnly
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.inventory_2_outlined,
                              title: hasAnyProducts
                                  ? 'Aucun produit trouvé'
                                  : 'Aucun produit enregistré',
                              message: hasAnyProducts
                                  ? _lowStockOnly
                                        ? 'Aucun produit n’est actuellement en stock faible.'
                                        : 'Essayez un autre mot-clé ou modifiez le filtre.'
                                  : 'Ajoutez votre premier produit pour commencer à suivre votre stock.',
                              actionLabel: hasAnyProducts
                                  ? null
                                  : 'Ajouter un produit',
                              onAction: hasAnyProducts ? null : _openCreate,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppTokens.screenPadding,
                          0,
                          AppTokens.screenPadding,
                          28,
                        ),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _ProductListItem(
                            product: products[index],
                            onTap: () => _openDetails(products[index]),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sortShortLabel(ProductSort sort) {
    switch (sort) {
      case ProductSort.name:
        return 'Nom A–Z';
      case ProductSort.quantityAsc:
        return 'Quantité ↑';
      case ProductSort.quantityDesc:
        return 'Quantité ↓';
      case ProductSort.priceAsc:
        return 'Prix ↑';
      case ProductSort.priceDesc:
        return 'Prix ↓';
      case ProductSort.recent:
        return 'Récents';
    }
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[AppTokens.primaryShadow],
      ),
      child: Material(
        color: AppColors.cobalt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cobalt,
      borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
        child: SizedBox(
          width: 50,
          height: 51,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              const Icon(Icons.tune_rounded, color: Colors.white, size: 21),
              if (active)
                Positioned(
                  right: 13,
                  top: 12,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.cobalt : Colors.white,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? null : const <BoxShadow>[AppTokens.cardShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 13,
                color: selected ? AppColors.amber : AppColors.amberDark,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductListItem extends StatelessWidget {
  const _ProductListItem({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reference = product.reference?.trim();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      borderRadius: 16,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          ProductAvatar(name: product.name, size: 42),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  <String>[
                    if (reference != null && reference.isNotEmpty) reference,
                    '${AppFormatters.money(product.unitPrice)} / '
                        '${product.unit.toLowerCase()}',
                  ].join(' · '),
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
            lowStock: product.isLowStock,
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 17,
          ),
        ],
      ),
    );
  }
}
