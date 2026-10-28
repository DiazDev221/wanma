import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../models/client.dart';

/// Accès SQLite aux clients.
class ClientRepository {
  ClientRepository(this._database);

  final AppDatabase _database;

  Future<List<Client>> getAll() async {
    final db = await _database.database;
    final rows = await db.query(
      'clients',
      orderBy: 'last_name COLLATE NOCASE ASC, first_name COLLATE NOCASE ASC',
    );
    return rows.map(Client.fromMap).toList(growable: false);
  }

  Future<Client?> findById(int id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _database.database;
    final rows = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  Future<Client?> findByPhone(
    String phone, {
    int? excludeId,
    DatabaseExecutor? executor,
  }) async {
    final normalized = AppFormatters.normalizePhone(phone);
    if (normalized.isEmpty) return null;
    final db = executor ?? await _database.database;
    final rows = await db.query(
      'clients',
      where: excludeId == null
          ? 'phone_normalized = ?'
          : 'phone_normalized = ? AND id <> ?',
      whereArgs: excludeId == null
          ? <Object?>[normalized]
          : <Object?>[normalized, excludeId],
      limit: 1,
    );
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  /// Crée un client. Un doublon de téléphone n'est autorisé que si
  /// [allowDuplicatePhone] vaut `true` après confirmation explicite.
  Future<Client> create(
    Client client, {
    bool allowDuplicatePhone = false,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _database.database;
    final duplicate = await findByPhone(client.phone, executor: db);
    if (duplicate != null && !allowDuplicatePhone) {
      throw DuplicatePhoneException(duplicate);
    }
    try {
      final id = await db.insert(
        'clients',
        client.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return client.copyWith(id: id);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const AppException('Ce client existe déjà.');
      }
      rethrow;
    }
  }

  Future<void> update(Client client, {bool allowDuplicatePhone = false}) async {
    if (client.id == null) {
      throw const ValidationException('Identifiant du client manquant.');
    }
    final duplicate = await findByPhone(client.phone, excludeId: client.id);
    if (duplicate != null && !allowDuplicatePhone) {
      throw DuplicatePhoneException(duplicate);
    }
    final db = await _database.database;
    final count = await db.update(
      'clients',
      <String, Object?>{
        'first_name': client.firstName.trim(),
        'last_name': client.lastName.trim(),
        'phone': client.phone.trim(),
        'phone_normalized': AppFormatters.normalizePhone(client.phone),
      },
      where: 'id = ?',
      whereArgs: <Object?>[client.id],
    );
    if (count == 0) {
      throw const AppException('Ce client n’existe plus.');
    }
  }

  Future<void> delete(int id) async {
    final db = await _database.database;
    final movementCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(*)
            FROM stock_out_details
            WHERE client_id = ?
            ''',
            <Object?>[id],
          ),
        ) ??
        0;
    if (movementCount > 0) {
      throw const AppException(
        'Suppression impossible : des sorties sont associées à ce client. '
        'Son historique doit être conservé.',
      );
    }
    final count = await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (count == 0) {
      throw const AppException('Ce client n’existe plus.');
    }
  }
}
