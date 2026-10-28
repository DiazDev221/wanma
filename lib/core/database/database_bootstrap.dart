import 'database_bootstrap_stub.dart'
    if (dart.library.io) 'database_bootstrap_io.dart'
    as implementation;

/// Prépare SQLite pour la plateforme courante.
///
/// Retourne le chemin de la base sur ordinateur, ou `null` lorsqu'il faut
/// laisser sqflite utiliser son répertoire par défaut (Android, iOS).
Future<String?> initializeDatabaseStorage() {
  return implementation.initializeDatabaseStorage();
}
