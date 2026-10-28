import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/product.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/avatars.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_sections.dart';
import '../../widgets/pickers.dart';
import '../products/product_form_screen.dart';

class StockEntryScreen extends StatefulWidget {
  const StockEntryScreen({super.key, this.initialProduct});

  final Product? initialProduct;

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  Product? _selectedProduct;
  bool _saving = false;
  bool _productError = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    if (_selectedProduct != null) {
      _priceController.text = _selectedProduct!.unitPrice.toString();
    }
    _quantityController.addListener(_onPreviewChanged);
    _priceController.addListener(_onPreviewChanged);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onPreviewChanged);
    _priceController.removeListener(_onPreviewChanged);
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPreviewChanged() {
    if (mounted) setState(() {});
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _productError = false;
      _priceController.text = product.unitPrice.toString();
    });
  }

  double? get _quantity {
    final value = _quantityController.text.replaceAll(',', '.').trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  int? get _price {
    final value = _priceController.text.replaceAll(' ', '').trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  int? get _total {
    final qty = _quantity;
    final price = _price;
    if (qty == null || price == null || qty <= 0) return null;
    return (qty * price).round();
  }

  Future<void> _addProduct() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProductFormScreen()));
    if (!mounted) return;
    final products = context.read<AppState>().products;
    if (products.length == 1) {
      _selectProduct(products.first);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _productError = _selectedProduct == null);
    final valid = _formKey.currentState?.validate() ?? false;
    if (_selectedProduct == null || !valid) return;

    final product = _selectedProduct!;
    setState(() => _saving = true);
    try {
      final movement = await context.read<AppState>().recordStockIn(
        productId: product.id!,
        quantity: _quantity!,
        unitPrice: _price,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      final updated = context.read<AppState>().productById(product.id!);
      AppFeedback.success(
        context,
        'Entrée enregistrée. Nouveau stock de ${product.name} : '
        '${AppFormatters.quantity(updated?.quantity ?? movement.quantity)} '
        '${product.unit.toLowerCase()}.',
      );
      Navigator.of(context).pop(movement);
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentProduct = _selectedProduct?.id == null
        ? _selectedProduct
        : appState.productById(_selectedProduct!.id!);

    if (appState.products.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle entrée')),
        body: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Aucun produit à approvisionner',
          message: 'Ajoutez d’abord un produit au catalogue pour enregistrer une entrée de stock.',
          actionLabel: 'Ajouter un produit',
          onAction: _addProduct,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle entrée')),
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
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: AppColors.mint),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(_saving ? 'Enregistrement...' : 'Enregistrer l’entrée'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: FormContent(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.mintSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.add_box_outlined,
                        color: AppColors.mint,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Entrée de stock',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Approvisionnez un produit du magasin.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FormSectionTitle(
                  title: 'Produit concerné',
                  subtitle: 'Sélectionnez le produit reçu.',
                  icon: Icons.inventory_2_outlined,
                ),
                ProductPickerField(
                  selected: currentProduct,
                  onChanged: _selectProduct,
                  errorText: _productError
                      ? 'Veuillez sélectionner un produit.'
                      : null,
                ),
                if (currentProduct != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const <BoxShadow>[AppTokens.cardShadow],
                    ),
                    child: Row(
                      children: <Widget>[
                        ProductAvatar(name: currentProduct.name, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                currentProduct.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                'Stock actuel : '
                                '${AppFormatters.quantity(currentProduct.quantity)} '
                                '${currentProduct.unit.toLowerCase()}',
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
                        Text(
                          AppFormatters.money(currentProduct.unitPrice),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.cobalt,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FormSectionTitle(
                  title: 'Détails de l’entrée',
                  subtitle: 'La quantité et la date sont obligatoires. Le prix reste facultatif.',
                  icon: Icons.edit_note_rounded,
                ),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  inputFormatters: quantityInputFormatters,
                  decoration: InputDecoration(
                    labelText: 'Quantité entrée *',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.add_rounded),
                    suffixText: currentProduct?.unit.toLowerCase(),
                  ),
                  validator: (value) =>
                      FormValidators.quantity(value, strictlyPositive: true),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Prix unitaire (optionnel)',
                    hintText: currentProduct == null
                        ? 'Prix d’achat'
                        : currentProduct.unitPrice.toString(),
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: AppConstants.currency,
                    helperText: currentProduct == null
                        ? null
                        : 'Prérempli avec le prix actuel du produit.',
                  ),
                  validator: (value) =>
                      FormValidators.price(value, optional: true),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Observation (optionnel)',
                    hintText: 'Ex. Livraison du fournisseur...',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 34),
                      child: Icon(Icons.notes_rounded),
                    ),
                  ),
                ),
                if (_total != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.mintSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.trending_up_rounded,
                          color: AppColors.mint,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Valeur de l’entrée',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.mint,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          AppFormatters.money(_total!),
                          style: const TextStyle(
                            color: AppColors.mint,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (currentProduct != null && _quantity != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Nouveau stock prévu : '
                    '${AppFormatters.quantity(currentProduct.quantity + _quantity!)} '
                    '${currentProduct.unit.toLowerCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const InfoBanner(
                  text:
                      'L’entrée sera enregistrée immédiatement. Le stock du '
                      'produit augmentera automatiquement.',
                  icon: Icons.shield_outlined,
                  color: AppColors.mint,
                  backgroundColor: AppColors.mintSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
