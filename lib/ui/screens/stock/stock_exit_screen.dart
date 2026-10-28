import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/client.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_sections.dart';
import '../../widgets/pickers.dart';
import '../clients/client_form_screen.dart';
import '../products/product_form_screen.dart';

enum _ClientMode { existing, newClient }

class StockExitScreen extends StatefulWidget {
  const StockExitScreen({super.key, this.initialProduct, this.initialClient});

  final Product? initialProduct;
  final Client? initialClient;

  @override
  State<StockExitScreen> createState() => _StockExitScreenState();
}

class _StockExitScreenState extends State<StockExitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  Product? _selectedProduct;
  Client? _selectedClient;
  _ClientMode _clientMode = _ClientMode.existing;
  bool _saving = false;
  bool _productError = false;
  bool _clientError = false;
  bool _isCredit = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    _selectedClient = widget.initialClient;
    if (_selectedProduct != null) {
      _priceController.text = _selectedProduct!.unitPrice.toString();
    }
    _quantityController.addListener(_onFieldChanged);
    _priceController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onFieldChanged);
    _priceController.removeListener(_onFieldChanged);
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _productError = false;
      _priceController.text = product.unitPrice.toString();
    });
  }

  void _selectClient(Client client) {
    setState(() {
      _selectedClient = client;
      _clientError = false;
    });
  }

  void _setClientMode(_ClientMode mode) {
    if (_clientMode == mode) return;
    setState(() {
      _clientMode = mode;
      _clientError = false;
    });
  }

  double? get _quantity {
    final value = _quantityController.text.replaceAll(',', '.').trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  int? get _typedPrice {
    final value = _priceController.text.replaceAll(' ', '').trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  int? get _appliedPrice => _typedPrice ?? _selectedProduct?.unitPrice;

  int? get _total {
    final qty = _quantity;
    final price = _appliedPrice;
    if (qty == null || price == null || qty <= 0) return null;
    return (qty * price).round();
  }

  Future<void> _addProduct() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProductFormScreen()));
    if (!mounted) return;
    final products = context
        .read<AppState>()
        .products
        .where((product) => product.quantity > 0)
        .toList();
    if (products.length == 1) _selectProduct(products.first);
  }

  Future<void> _addClientStandalone() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ClientFormScreen()));
    if (!mounted) return;
    final clients = context.read<AppState>().clients;
    if (clients.isNotEmpty && _selectedClient == null) {
      setState(() {
        _selectedClient = clients.firstWhere(
          (client) => client.phone == _phoneController.text.trim(),
          orElse: () => clients.last,
        );
      });
    }
  }

  Future<bool> _confirmDuplicate(DuplicatePhoneException exception) {
    return AppFeedback.confirm(
      context,
      title: 'Numéro déjà enregistré',
      message:
          '${exception.existingClient.firstName} '
          '${exception.existingClient.lastName} utilise déjà ce numéro. '
          'Voulez-vous créer un autre client avec ce même numéro ?',
      confirmLabel: 'Continuer',
      icon: Icons.people_alt_outlined,
    );
  }

  String? _validateQuantity(String? value) {
    final base = FormValidators.quantity(value, strictlyPositive: true);
    if (base != null) return base;
    final qty = _quantity;
    final product = _selectedProduct;
    if (qty != null && product != null && qty > product.quantity) {
      return 'Stock insuffisant : '
          '${AppFormatters.quantity(product.quantity)} '
          '${product.unit.toLowerCase()} disponible(s).';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _productError = _selectedProduct == null;
      _clientError =
          _clientMode == _ClientMode.existing && _selectedClient == null;
    });
    final formValid = _formKey.currentState?.validate() ?? false;
    if (_productError || _clientError || !formValid) return;

    final product = _selectedProduct!;
    if (product.id == null) {
      if (mounted) {
        AppFeedback.error(context, const AppException('Produit invalide.'));
      }
      return;
    }
    final qty = _quantity!;
    if (qty > product.quantity) {
      setState(() {});
      return;
    }

    final appState = context.read<AppState>();
    setState(() => _saving = true);
    try {
      var allowDuplicate = false;
      StockMovement? movement;
      var duplicateConfirmed = true;

      while (true) {
        try {
          movement = await appState.recordStockOut(
            productId: product.id!,
            quantity: qty,
            unitPrice: _typedPrice,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            clientId: _clientMode == _ClientMode.existing
                ? _selectedClient?.id
                : null,
            newClient: _clientMode == _ClientMode.newClient
                ? Client(
                    firstName: _firstNameController.text.trim(),
                    lastName: _lastNameController.text.trim(),
                    phone: _phoneController.text.trim(),
                    createdAt: DateTime.now(),
                  )
                : null,
            allowDuplicatePhone: allowDuplicate,
            isCredit: _isCredit,
          );
          break;
        } on DuplicatePhoneException catch (error) {
          if (!mounted) return;
          duplicateConfirmed = await _confirmDuplicate(error);
          if (!duplicateConfirmed) break;
          allowDuplicate = true;
        }
      }

      if (!mounted) return;
      if (movement == null || !duplicateConfirmed) return;

      final updatedProduct = appState.productById(product.id!);
      final clientName = movement.clientFullName.isEmpty
          ? (_selectedClient?.fullName ?? 'Nouveau client')
          : movement.clientFullName;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.mintSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.mint,
                size: 28,
              ),
            ),
            title: const Text('Sortie enregistrée'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  movement!.isCredit
                      ? 'La sortie a été enregistrée à crédit. Elle reste à '
                            'recouvrer jusqu’au remboursement du client.'
                      : 'La sortie a été enregistrée et le stock a été mis à jour.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: <Widget>[
                      _ConfirmLine(label: 'Produit', value: product.name),
                      _ConfirmLine(label: 'Client', value: clientName),
                      _ConfirmLine(
                        label: 'Quantité',
                        value:
                            '${AppFormatters.quantity(movement.quantity)} '
                            '${product.unit.toLowerCase()}',
                      ),
                      _ConfirmLine(
                        label: 'Montant total',
                        value: AppFormatters.money(movement.totalAmount),
                        emphasize: true,
                      ),
                      _ConfirmLine(
                        label: 'Paiement',
                        value: movement.isCredit
                            ? 'À crédit (non réglé)'
                            : 'Payé',
                      ),
                      _ConfirmLine(
                        label: 'Stock restant',
                        value:
                            '${AppFormatters.quantity(updatedProduct?.quantity ?? 0)} '
                            '${product.unit.toLowerCase()}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Terminé'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
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
    final availableProducts = appState.products
        .where((product) => product.quantity > 0)
        .toList();

    if (availableProducts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle sortie')),
        body: EmptyState(
          icon: Icons.inventory_2_outlined,
          title: appState.products.isEmpty
              ? 'Aucun produit en stock'
              : 'Aucun produit disponible',
          message: 'Ajoutez un produit ou enregistrez une entrée de stock avant de créer une sortie.',
          actionLabel: 'Ajouter un produit',
          onAction: _addProduct,
        ),
      );
    }

    final clients = appState.clients;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle sortie')),
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
            onPressed: _saving ? null : _submit,
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
              _saving
                  ? 'Enregistrement...'
                  : _isCredit
                  ? 'Valider la sortie à crédit'
                  : 'Valider la sortie',
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
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.cobaltSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: AppColors.cobalt,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Sortie de stock',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Identifiez le client et le produit remis.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FormSectionTitle(
                  title: 'Client concerné',
                  subtitle: 'Choisissez un client ou créez sa fiche ici.',
                  icon: Icons.person_outline_rounded,
                ),
                _ClientModeSelector(
                  mode: _clientMode,
                  onChanged: _setClientMode,
                ),
                const SizedBox(height: 12),
                if (_clientMode == _ClientMode.existing)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ClientPickerField(
                        selected: _selectedClient,
                        onChanged: _selectClient,
                        errorText: _clientError
                            ? 'Veuillez sélectionner un client.'
                            : null,
                      ),
                      if (clients.isEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        InfoBanner(
                          text:
                              'Aucun client n’est encore enregistré. Passez à '
                              '« Nouveau client » pour créer la fiche et la sortie '
                              'en une seule fois.',
                          icon: Icons.person_add_alt_1_rounded,
                          color: AppColors.cobalt,
                          backgroundColor: AppColors.cobaltSoft,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addClientStandalone,
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: const Text('Créer une fiche client'),
                        ),
                      ],
                    ],
                  )
                else
                  Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Prénom *',
                                hintText: 'Ex. Amadou',
                              ),
                              validator: (value) => FormValidators.personName(
                                value,
                                label: 'Le prénom',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nom *',
                                hintText: 'Ex. Ndiaye',
                              ),
                              validator: (value) => FormValidators.personName(
                                value,
                                label: 'Le nom',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+ ()-]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Téléphone *',
                          hintText: 'Ex. 77 123 45 67',
                        ),
                        validator: FormValidators.phone,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cette fiche sera enregistrée avec la sortie. '
                        'En cas d’échec, aucune des deux opérations ne sera validée.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                FormSectionTitle(
                  title: 'Produit et quantité',
                  subtitle:
                      'La sortie ne peut pas dépasser le stock disponible.',
                  icon: Icons.inventory_2_outlined,
                ),
                ProductPickerField(
                  selected: currentProduct,
                  onChanged: _selectProduct,
                  onlyInStock: true,
                  errorText: _productError
                      ? 'Veuillez sélectionner un produit.'
                      : null,
                ),
                if (currentProduct != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Disponible : '
                          '${AppFormatters.quantity(currentProduct.quantity)} '
                          '${currentProduct.unit.toLowerCase()} · '
                          '${AppFormatters.money(currentProduct.unitPrice)} / '
                          '${currentProduct.unit.toLowerCase()}',
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  inputFormatters: quantityInputFormatters,
                  decoration: InputDecoration(
                    labelText: 'Quantité sortie *',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.remove_rounded),
                    suffixText: currentProduct?.unit.toLowerCase(),
                  ),
                  validator: _validateQuantity,
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
                    labelText: 'Prix unitaire appliqué',
                    hintText: currentProduct?.unitPrice.toString() ?? '0',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: AppConstants.currency,
                    helperText:
                        'Le prix appliqué est conservé dans l’historique.',
                  ),
                  validator: (value) =>
                      FormValidators.price(value, optional: true),
                ),
                const SizedBox(height: 14),
                Material(
                  color: _isCredit ? AppColors.amberSoft : Colors.white,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _isCredit ? AppColors.amber : AppColors.line,
                    ),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _isCredit,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _isCredit = value),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    secondary: Icon(
                      _isCredit
                          ? Icons.schedule_rounded
                          : Icons.payments_outlined,
                      color: _isCredit ? AppColors.amberDark : AppColors.muted,
                    ),
                    title: const Text(
                      'Vente à crédit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _isCredit
                          ? 'Le client paie plus tard. La sortie restera à '
                                'recouvrer jusqu’au remboursement.'
                          : 'Le client paie maintenant. Activez cette option '
                                's’il prend les produits à crédit.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
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
                    hintText: 'Ex. Paiement en espèces...',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 34),
                      child: Icon(Icons.notes_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cobaltSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Montant total',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              _total == null
                                  ? '—'
                                  : AppFormatters.money(_total!),
                              maxLines: 1,
                              style: const TextStyle(
                                color: AppColors.cobalt,
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (currentProduct != null &&
                          _quantity != null) ...<Widget>[
                        const Divider(height: 18, color: AppColors.line),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Stock après sortie',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontSize: 11),
                              ),
                            ),
                            Text(
                              '${AppFormatters.quantity((currentProduct.quantity - (_quantity ?? 0)).clamp(0, double.infinity))} '
                              '${currentProduct.unit.toLowerCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color:
                                    _quantity != null &&
                                        _quantity! > currentProduct.quantity
                                    ? AppColors.coral
                                    : AppColors.cobalt,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 18, color: AppColors.line),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Paiement',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 11),
                            ),
                          ),
                          Text(
                            _isCredit ? 'À crédit' : 'Payé',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _isCredit
                                  ? AppColors.amberDark
                                  : AppColors.mint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const InfoBanner(
                  text:
                      'L’enregistrement de la sortie et la mise à jour du stock '
                      'sont réalisés dans une seule transaction. En cas d’erreur, '
                      'aucune donnée n’est modifiée.',
                  icon: Icons.shield_outlined,
                  color: AppColors.cobalt,
                  backgroundColor: AppColors.cobaltSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientModeSelector extends StatelessWidget {
  const _ClientModeSelector({required this.mode, required this.onChanged});

  final _ClientMode mode;
  final ValueChanged<_ClientMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[AppTokens.cardShadow],
      ),
      child: Row(
        children: <Widget>[
          _Tab(
            label: 'Client existant',
            icon: Icons.person_search_outlined,
            selected: mode == _ClientMode.existing,
            onTap: () => onChanged(_ClientMode.existing),
          ),
          const SizedBox(width: 4),
          _Tab(
            label: 'Nouveau client',
            icon: Icons.person_add_alt_1_outlined,
            selected: mode == _ClientMode.newClient,
            onTap: () => onChanged(_ClientMode.newClient),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
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
    return Expanded(
      child: Material(
        color: selected ? AppColors.cobaltSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 17,
                  color: selected ? AppColors.cobalt : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.cobalt : AppColors.muted,
                    ),
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

class _ConfirmLine extends StatelessWidget {
  const _ConfirmLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11.5,
                color: emphasize ? AppColors.cobalt : AppColors.ink,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
