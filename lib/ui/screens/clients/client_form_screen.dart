import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/client.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/form_sections.dart';

class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, this.client});

  final Client? client;

  bool get isEditing => client != null;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  bool _saving = false;
  bool _pickingContact = false;
  final _contactPicker = FlutterNativeContactPicker();

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.client?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.client?.lastName ?? '',
    );
    _phoneController = TextEditingController(text: widget.client?.phone ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDuplicate(DuplicatePhoneException exception) {
    return AppFeedback.confirm(
      context,
      title: 'Numéro déjà enregistré',
      message:
          '${exception.existingClient.firstName} '
          '${exception.existingClient.lastName} utilise déjà ce numéro '
          '(${exception.existingClient.phone}).\n\n'
          'Souhaitez-vous tout de même enregistrer ce client ?',
      confirmLabel: 'Enregistrer quand même',
      icon: Icons.people_alt_outlined,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final appState = context.read<AppState>();
    setState(() => _saving = true);
    var allowDuplicate = false;
    try {
      if (widget.client == null) {
        final draft = Client(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          createdAt: DateTime.now(),
        );
        while (true) {
          try {
            await appState.addClient(
              draft,
              allowDuplicatePhone: allowDuplicate,
            );
            break;
          } on DuplicatePhoneException catch (error) {
            if (!mounted) return;
            final confirmed = await _confirmDuplicate(error);
            if (!confirmed) return;
            allowDuplicate = true;
          }
        }
      } else {
        final updated = widget.client!.copyWith(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        while (true) {
          try {
            await appState.updateClient(
              updated,
              allowDuplicatePhone: allowDuplicate,
            );
            break;
          } on DuplicatePhoneException catch (error) {
            if (!mounted) return;
            final confirmed = await _confirmDuplicate(error);
            if (!confirmed) return;
            allowDuplicate = true;
          }
        }
      }

      if (!mounted) return;
      AppFeedback.success(
        context,
        widget.isEditing
            ? 'La fiche client a été mise à jour.'
            : 'Le client a été ajouté avec succès.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importContact() async {
    if (_pickingContact || _saving) return;
    setState(() => _pickingContact = true);
    try {
      final contact = await _contactPicker.selectPhoneNumber();
      if (!mounted || contact == null) return;

      final phone = contact.selectedPhoneNumber?.trim();
      if (phone == null || phone.isEmpty) {
        AppFeedback.error(
          context,
          const AppException(
            'Ce contact ne contient pas de numéro de téléphone.',
          ),
        );
        return;
      }

      final name = contact.fullName?.trim();
      if (name != null && name.isNotEmpty) {
        final parts = name.split(RegExp(r'\s+'));
        _firstNameController.text = parts.first;
        _lastNameController.text = parts.length > 1
            ? parts.skip(1).join(' ')
            : '';
      }
      _phoneController.text = phone;
      _formKey.currentState?.validate();
    } on PlatformException {
      if (mounted) {
        AppFeedback.error(
          context,
          const AppException('Impossible d’ouvrir le répertoire du téléphone.'),
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _pickingContact = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier le client' : 'Ajouter un client',
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
              _saving ? 'Enregistrement...' : 'Enregistrer le client',
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
                  title: 'Coordonnées du client',
                  subtitle: 'Le prénom et le nom apparaîtront dans l’historique des sorties.',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 8),
                if (!widget.isEditing) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: _pickingContact || _saving
                        ? null
                        : _importContact,
                    icon: _pickingContact
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.contacts_outlined),
                    label: Text(
                      _pickingContact
                          ? 'Ouverture du répertoire...'
                          : 'Choisir dans le répertoire',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    hintText: 'Ex. Amadou',
                    prefixIcon: Icon(Icons.badge_outlined),
                    counterText: '',
                  ),
                  validator: (value) =>
                      FormValidators.personName(value, label: 'Le prénom'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    hintText: 'Ex. Ndiaye',
                    prefixIcon: Icon(Icons.badge_outlined),
                    counterText: '',
                  ),
                  validator: (value) =>
                      FormValidators.personName(value, label: 'Le nom'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  maxLength: 25,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone *',
                    hintText: 'Ex. 77 123 45 67',
                    prefixIcon: Icon(Icons.phone_outlined),
                    counterText: '',
                  ),
                  validator: FormValidators.phone,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
                const InfoBanner(
                  text:
                      'Le numéro est conservé sous forme de texte afin de garder '
                      'l’indicatif international et les zéros initiaux.',
                  icon: Icons.info_outline_rounded,
                  color: AppColors.cobalt,
                  backgroundColor: AppColors.cobaltSoft,
                ),
                const SizedBox(height: 12),
                const InfoBanner(
                  text:
                      'Un numéro déjà utilisé déclenchera une alerte. Vous pourrez '
                      'confirmer l’enregistrement si c’est volontaire.',
                  icon: Icons.shield_outlined,
                  color: AppColors.amberDark,
                  backgroundColor: AppColors.amberSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
