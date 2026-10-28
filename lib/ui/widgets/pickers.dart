import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/search.dart';
import '../../data/models/client.dart';
import '../../data/models/product.dart';
import '../../state/app_state.dart';
import 'avatars.dart';
import 'empty_state.dart';

/// Sélecteur de produit avec recherche locale.
class ProductPickerField extends StatelessWidget {
  const ProductPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.onlyInStock = false,
    this.label = 'Produit',
  });

  final Product? selected;
  final ValueChanged<Product> onChanged;
  final String? errorText;
  final bool enabled;
  final bool onlyInStock;
  final String label;

  Future<void> _open(BuildContext context) async {
    final products = context.read<AppState>().products;
    final result = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProductPickerSheet(
        products: onlyInStock
            ? products.where((product) => product.quantity > 0).toList()
            : products,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          prefixIcon: const Icon(Icons.inventory_2_outlined, size: 21),
          suffixIcon: Icon(
            enabled ? Icons.unfold_more_rounded : Icons.lock_outline_rounded,
            size: 20,
          ),
          enabled: enabled,
          border: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
                  borderSide: const BorderSide(color: AppColors.coral),
                )
              : null,
        ),
        child: selected == null
            ? const Text(
                'Sélectionner un produit',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              )
            : Row(
                children: <Widget>[
                  ProductAvatar(name: selected!.name, size: 28),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      selected!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${AppFormatters.quantity(selected!.quantity)} '
                    '${selected!.unit.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.products});

  final List<Product> products;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeForSearch(_query);
    final products = widget.products
        .where((product) {
          if (normalized.isEmpty) return true;
          final haystack = normalizeForSearch(
            '${product.name} ${product.reference ?? ''} ${product.unit}',
          );
          return haystack.contains(normalized);
        })
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Choisir un produit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou référence...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: products.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Aucun produit trouvé',
                      message:
                          'Ajoutez un produit ou modifiez votre recherche.',
                      compact: true,
                    )
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(product),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: <Widget>[
                                  ProductAvatar(name: product.name, size: 44),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${AppFormatters.money(product.unitPrice)} / ${product.unit.toLowerCase()}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: product.isLowStock
                                          ? AppColors.amberSoft
                                          : AppColors.mintSoft,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      '${AppFormatters.quantity(product.quantity)} '
                                      '${product.unit.toLowerCase()}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: product.isLowStock
                                            ? AppColors.amberDark
                                            : AppColors.mint,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur de client avec recherche par nom ou téléphone.
class ClientPickerField extends StatelessWidget {
  const ClientPickerField({
    super.key,
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  final Client? selected;
  final ValueChanged<Client> onChanged;
  final String? errorText;

  Future<void> _open(BuildContext context) async {
    final clients = context.read<AppState>().clients;
    final result = await showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ClientPickerSheet(clients: clients),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: 'Client',
          errorText: errorText,
          prefixIcon: const Icon(Icons.person_search_outlined, size: 21),
          suffixIcon: const Icon(Icons.unfold_more_rounded, size: 20),
        ),
        child: selected == null
            ? const Text(
                'Rechercher un client...',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              )
            : Row(
                children: <Widget>[
                  ClientAvatar(
                    firstName: selected!.firstName,
                    lastName: selected!.lastName,
                    size: 30,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          selected!.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          selected!.phone,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
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

class _ClientPickerSheet extends StatefulWidget {
  const _ClientPickerSheet({required this.clients});

  final List<Client> clients;

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeForSearch(_query);
    final clients = widget.clients
        .where((client) {
          if (normalized.isEmpty) return true;
          return normalizeForSearch(
            '${client.firstName} ${client.lastName} ${client.phone}',
          ).contains(normalized);
        })
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Choisir un client',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Nom, prénom ou téléphone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: clients.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Aucun client trouvé',
                      message: 'Créez un nouveau client depuis l’onglet prévu.',
                      compact: true,
                    )
                  : ListView.separated(
                      itemCount: clients.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final client = clients[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(client),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: <Widget>[
                                  ClientAvatar(
                                    firstName: client.firstName,
                                    lastName: client.lastName,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          client.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          client.phone,
                                          style: const TextStyle(
                                            fontSize: 10.5,
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
