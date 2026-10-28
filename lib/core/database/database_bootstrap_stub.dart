/// Le web n'utilise pas le backend SQLite natif : rien à préparer ici.
Future<String?> initializeDatabaseStorage() {
  return Future<String?>.value();
}
