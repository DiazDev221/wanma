import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatars.dart';
import '../../widgets/empty_state.dart';
import '../products/product_detail_screen.dart';
import '../stock/stock_entry_screen.dart';

/// Liste complète des produits à surveiller.
class LowStockScreen extends StatelessWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final products =
        appState.products
            .where((product) => product.isLowStock)
            .toList(growable: false)
          ..sort((a, b) => a.quantity.compareTo(b.quantity));

    return Scaffold(
      appBar: AppBar(title: const Text('Stock à surveiller')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(AppTokens.heroRadius),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.amberDark,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          products.isEmpty
                              ? 'Tout est sous contrôle'
                              : '${products.length} produit'
                                    '${products.length > 1 ? 's' : ''} '
                                    'à réapprovisionner',
                          style: const TextStyle(
                            color: AppColors.amberDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Les quantités affichées sont inférieures ou égales '
                          'au seuil d’alerte.',
                          style: TextStyle(
                            color: AppColors.amberDark,
                            fontSize: 10.5,
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
            const SizedBox(height: 18),
            if (products.isEmpty)
              const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Aucun produit à surveiller',
                message:
                    'Tous vos produits sont au-dessus de leur seuil d’alerte.',
              )
            else ...<Widget>[
              const SectionHeader(
                title: 'Produits concernés',
                subtitle: 'Touchez un produit pour ouvrir sa fiche.',
              ),
              for (var i = 0; i < products.length; i++) ...<Widget>[
                _LowStockTile(product: products[i]),
                if (i < products.length - 1) const SizedBox(height: 9),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(13),
      onTap: product.id == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductDetailScreen(productId: product.id!),
                ),
              );
            },
      child: Row(
        children: <Widget>[
          ProductAvatar(name: product.name, size: 46),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.amberSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${AppFormatters.quantity(product.quantity)} '
                        '${product.unit.toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.amberDark,
                        ),
                      ),
                    ),
                    Text(
                      'seuil ${AppFormatters.quantity(product.lowStockThreshold)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StockEntryScreen(initialProduct: product),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.add_rounded, size: 14, color: AppColors.mint),
                    SizedBox(width: 2),
                    Text(
                      'Entrée',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
