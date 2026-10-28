import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/app_exception.dart';
import '../models/stock_movement.dart';

/// Accès en lecture à l'historique des mouvements.
///
/// Les écritures passent exclusivement par InventoryService afin de garantir
/// une transaction atomique stock + historique.
class MovementRepository {
  MovementRepository(this._database);

  final AppDatabase _database;

  static const String _baseSelect = '''
    SELECT
      m.*,
      p.name AS product_name,
      p.reference AS product_reference,
      p.unit AS product_unit,
      c.id AS client_id,
      c.first_name AS client_first_name,
      c.last_name AS client_last_name,
      c.phone AS client_phone
    FROM stock_movements m
    INNER JOIN products p ON p.id = m.product_id
    LEFT JOIN stock_out_details d ON d.movement_id = m.id
    LEFT JOIN clients c ON c.id = d.client_id
  ''';

  Future<List<StockMovement>> getAll({int? limit}) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '$_baseSelect ORDER BY m.movement_date DESC, m.id DESC'
      '${limit == null ? '' : ' LIMIT $limit'}',
    );
    return rows.map(StockMovement.fromMap).toList(growable: false);
  }

  Future<StockMovement?> findById(int id) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE m.id = ? LIMIT 1',
      <Object?>[id],
    );
    return rows.isEmpty ? null : StockMovement.fromMap(rows.first);
  }

  Future<List<StockMovement>> getForProduct(int productId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE m.product_id = ? '
      'ORDER BY m.movement_date DESC, m.id DESC',
      <Object?>[productId],
    );
    return rows.map(StockMovement.fromMap).toList(growable: false);
  }

  Future<List<StockMovement>> getForClient(int clientId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '$_baseSelect WHERE c.id = ? '
      'ORDER BY m.movement_date DESC, m.id DESC',
      <Object?>[clientId],
    );
    return rows.map(StockMovement.fromMap).toList(growable: false);
  }

  /// Vérifie l'existence d'au moins un mouvement, notamment avant de
  /// supprimer un client ou un produit.
  Future<bool> existsForProduct(int productId) async {
    final db = await _database.database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM stock_movements WHERE product_id = ? LIMIT 1',
        <Object?>[productId],
      ),
    );
    return (result ?? 0) > 0;
  }

  Future<bool> existsForClient(int clientId) async {
    final db = await _database.database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM stock_out_details WHERE client_id = ? LIMIT 1',
        <Object?>[clientId],
      ),
    );
    return (result ?? 0) > 0;
  }

  /// Vérifie l'intégrité d'un mouvement avant toute opération sensible.
  Future<void> assertExists(int id) async {
    final movement = await findById(id);
    if (movement == null) {
      throw const AppException('Cette opération n’existe plus.');
    }
  }
}
