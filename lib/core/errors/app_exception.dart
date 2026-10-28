import '../../data/models/client.dart';

/// Erreur métier destinée à être affichée telle quelle à l'utilisateur.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Signale qu'un numéro de téléphone existe déjà.
///
/// L'utilisateur peut confirmer explicitement la création d'un doublon.
class DuplicatePhoneException extends AppException {
  DuplicatePhoneException(this.existingClient)
    : super(
        'Ce numéro de téléphone est déjà enregistré pour '
        '${existingClient.firstName} ${existingClient.lastName}.',
      );

  final Client existingClient;
}

/// Erreur liée à une quantité de stock insuffisante ou invalide.
class StockException extends AppException {
  const StockException(super.message);
}

/// Erreur de validation d'un formulaire.
class ValidationException extends AppException {
  const ValidationException(super.message);
}
