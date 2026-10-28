import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/product.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/form_sections.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  bool get isEditing => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _referenceController;
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _thresholdController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _customUnitController;
  late String _selectedUnit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _referenceController = TextEditingController(
      text: product?.reference ?? '',
    );
    _priceController = TextEditingController(
      text: product == null ? '' : product.unitPrice.toString(),
    );
    _quantityController = TextEditingController(text: '0');
    _thresholdController = TextEditingController(
      text: product == null ? '5' : _formatNumber(product.lowStockThreshold),
    );
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    final unit = product?.unit ?? 'Pièce';
    if (kProductUnits.contains(unit)) {
      _selectedUnit = unit;
      _customUnitController = TextEditingController();
    } else {
      _selectedUnit = 'Autre';
      _customUnitController = TextEditingController(text: unit);
    }
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString().replaceAll('.', ',');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _referenceController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    _descriptionController.dispose();
    _customUnitController.dispose();
    super.dispose();
  }

  String get _unit {
    if (_selectedUnit == 'Autre') {
      return _customUnitController.text.trim();
    }
    return _selectedUnit;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final appState = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final unitPrice = int.parse(_priceController.text.replaceAll(' ', ''));
      final threshold =
          double.tryParse(
            _thresholdController.text.replaceAll(',', '.').replaceAll(' ', ''),
          ) ??
          5;
      final reference = _referenceController.text.trim();
      final description = _descriptionController.text.trim();

      if (widget.product == null) {
        final initialQuantity =
            double.tryParse(
              _quantityController.text.replaceAll(',', '.').replaceAll(' ', ''),
            ) ??
            0;
        await appState.addProduct(
          name: _nameController.text.trim(),
          reference: reference.isEmpty ? null : reference,
          unitPrice: unitPrice,
          initialQuantity: initialQuantity,
          unit: _unit,
          lowStockThreshold: threshold,
          description: description.isEmpty ? null : description,
        );
      } else {
        final existing = widget.product!;
        final updated = existing.copyWith(
          name: _nameController.text.trim(),
          reference: reference.isEmpty ? null : reference,
          clearReference: reference.isEmpty,
          unitPrice: unitPrice,
          unit: _unit,
          lowStockThreshold: threshold,
          description: description.isEmpty ? null : description,
          clearDescription: description.isEmpty,
          updatedAt: DateTime.now(),
        );
        await appState.updateProduct(updated);
      }

      if (!mounted) return;
      AppFeedback.success(
        context,
        widget.isEditing
            ? 'Les informations du produit ont été mises à jour.'
            : 'Le produit a été ajouté avec succès.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier le produit' : 'Ajouter un produit',
        ),
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
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              _saving ? 'Enregistrement...' : 'Enregistrer le produit',
            ),
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
                const FormSectionTitle(
                  title: 'Informations du produit',
                  subtitle: 'Les champs marqués d’un astérisque sont requis.',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Nom du produit *',
                    hintText: 'Ex. Riz parfumé',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                    counterText: '',
                  ),
                  validator: FormValidators.productName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _referenceController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Référence (optionnel)',
                    hintText: 'Ex. RIZ001',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                    counterText: '',
                  ),
                  validator: FormValidators.optionalReference,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Prix unitaire *',
                    hintText: '0',
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: AppConstants.currency,
                  ),
                  validator: FormValidators.price,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Unité de mesure *',
                    prefixIcon: Icon(Icons.straighten_rounded),
                  ),
                  items: kProductUnits
                      .map(
                        (unit) => DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedUnit = value);
                  },
                ),
                if (_selectedUnit == 'Autre') ...<Widget>[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _customUnitController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Précisez l’unité *',
                      hintText: 'Ex. Bidon, paquet, plateau...',
                      prefixIcon: Icon(Icons.edit_outlined),
                      counterText: '',
                    ),
                    validator: (value) =>
                        FormValidators.requiredText(value, label: 'L’unité'),
                  ),
                ],
                if (!widget.isEditing) ...<Widget>[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: quantityInputFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Quantité initiale',
                      hintText: '0',
                      prefixIcon: Icon(Icons.add_box_outlined),
                      suffixText: 'en stock',
                    ),
                    validator: (value) =>
                        FormValidators.quantity(value, optional: true),
                  ),
                  const SizedBox(height: 8),
                  const InfoBanner(
                    text:
                        'La quantité initiale est automatiquement enregistrée '
                        'comme une entrée de stock dans l’historique.',
                    icon: Icons.history_rounded,
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 14),
                  InfoBanner(
                    text:
                        'Quantité actuelle : ${_formatNumber(widget.product!.quantity)} '
                        '${widget.product!.unit.toLowerCase()}. Pour ajuster le stock, '
                        'utilisez une entrée ou une sortie.',
                    icon: Icons.inventory_rounded,
                    color: AppColors.cobalt,
                    backgroundColor: AppColors.cobaltSoft,
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _thresholdController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: quantityInputFormatters,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Seuil d’alerte de stock faible',
                    hintText: '5',
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                    helperText: 'Un badge d’alerte apparaît lorsque le stock atteint ce seuil.',
                  ),
                  validator: FormValidators.threshold,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    hintText: 'Ex. Riz parfumé de qualité supérieure...',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 54),
                      child: Icon(Icons.notes_rounded),
                    ),
                  ),
                  validator: FormValidators.optionalDescription,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
