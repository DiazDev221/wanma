import '../../core/utils/formatters.dart';

/// Validateurs de formulaires réutilisables, en français.
abstract final class FormValidators {
  static String? requiredText(String? value, {String label = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label est obligatoire.';
    }
    return null;
  }

  static String? personName(String? value, {String label = 'Le nom'}) {
    final required = requiredText(value, label: label);
    if (required != null) return required;
    final trimmed = value!.trim();
    if (trimmed.length < 2) {
      return '$label doit contenir au moins 2 caractères.';
    }
    if (trimmed.length > 80) {
      return '$label ne peut pas dépasser 80 caractères.';
    }
    return null;
  }

  static String? productName(String? value) {
    final base = personName(value, label: 'Le nom du produit');
    if (base != null) return base;
    if (value!.trim().length > 120) {
      return 'Le nom du produit ne peut pas dépasser 120 caractères.';
    }
    return null;
  }

  static String? optionalReference(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length > 50) {
      return 'La référence ne peut pas dépasser 50 caractères.';
    }
    return null;
  }

  static String? optionalDescription(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length > 500) {
      return 'La description ne peut pas dépasser 500 caractères.';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le numéro de téléphone est obligatoire.';
    }
    final normalized = AppFormatters.normalizePhone(value);
    final digits = normalized.replaceAll('+', '');
    if (digits.length < 7) {
      return 'Le numéro de téléphone est trop court.';
    }
    if (digits.length > 15) {
      return 'Le numéro de téléphone est trop long.';
    }
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(value.trim())) {
      return 'Le numéro contient des caractères non autorisés.';
    }
    return null;
  }

  static String? price(String? value, {bool optional = false}) {
    if (value == null || value.trim().isEmpty) {
      return optional ? null : 'Le prix est obligatoire.';
    }
    final normalized = value.replaceAll(' ', '').replaceAll(',', '.');
    final parsed = int.tryParse(normalized);
    if (parsed == null) {
      return 'Saisissez un prix entier valide.';
    }
    if (parsed < 0) {
      return 'Le prix ne peut pas être négatif.';
    }
    if (parsed > 999999999999) {
      return 'Le prix saisi est trop élevé.';
    }
    return null;
  }

  static String? quantity(
    String? value, {
    bool optional = false,
    bool strictlyPositive = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (optional) return null;
      return 'La quantité est obligatoire.';
    }
    final parsed = double.tryParse(
      value.replaceAll(',', '.').replaceAll(' ', ''),
    );
    if (parsed == null) {
      return 'Saisissez une quantité valide.';
    }
    if (parsed < 0) {
      return 'La quantité ne peut pas être négative.';
    }
    if (strictlyPositive && parsed <= 0) {
      return 'La quantité doit être supérieure à zéro.';
    }
    if (parsed > 999999999) {
      return 'La quantité saisie est trop élevée.';
    }
    return null;
  }

  static String? threshold(String? value) {
    return quantity(value, optional: true);
  }

  static String? pin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Saisissez votre code PIN.';
    }
    if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
      return 'Le code PIN doit contenir 4 chiffres.';
    }
    return null;
  }
}
