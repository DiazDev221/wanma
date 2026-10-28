import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/app_exception.dart';
import '../models/product.dart';

/// Accès SQLite aux produits. Les mouvements ne sont volontairement jamais
/// supprimés avec un produit : l'historique doit rester intact.
class ProductRepository {
  ProductRepository(this._database);

  final AppDatabase _database;

  Future<List<Product>> getAll() async {
    final db = await _database.database;
    final rows = await db.query('products', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Product.fromMap).toList(growable: false);
  }

  Future<Product?> findById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<List<Product>> getLowStock() async {
    final db = await _database.database;
    final rows = await db.query(
      'products',
      where: 'quantity <= low_stock_threshold',
      orderBy: 'quantity ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList(growable: false);
  }

  Future<Product?> findByReference(String reference, {int? excludeId}) async {
    final cleaned = reference.trim();
    if (cleaned.isEmpty) return null;
    final db = await _database.database;
    final rows = await db.query(
      'products',
      where: excludeId == null
          ? 'reference = ? COLLATE NOCASE'
          : 'reference = ? COLLATE NOCASE AND id <> ?',
      whereArgs: excludeId == null
          ? <Object?>[cleaned]
          : <Object?>[cleaned, excludeId],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  /// Met à jour la fiche produit. La quantité est exclue : elle ne peut varier
  /// que via un mouvement de stock.
  Future<void> update(Product product) async {
    if (product.id == null) {
      throw const ValidationException('Identifiant du produit manquant.');
    }
    final existingReference = await findByReference(
      product.reference ?? '',
      excludeId: product.id,
    );
    if (existingReference != null) {
      throw const ValidationException(
        'Cette référence est déjà utilisée par un autre produit.',
      );
    }

    final db = await _database.database;
    try {
      final count = await db.update(
        'products',
        <String, Object?>{
          'name': product.name.trim(),
          'reference': _nullable(product.reference),
          'unit_price': product.unitPrice,
          'unit': product.unit.trim(),
          'low_stock_threshold': product.lowStockThreshold,
          'description': _nullable(product.description),
          'updated_at': product.updatedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: <Object?>[product.id],
      );
      if (count == 0) {
        throw const AppException('Ce produit n’existe plus.');
      }
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const ValidationException(
          'Cette référence est déjà utilisée par un autre produit.',
        );
      }
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    final db = await _database.database;
    final movementCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM stock_movements WHERE product_id = ?',
            <Object?>[id],
          ),
        ) ??
        0;
    if (movementCount > 0) {
      throw const AppException(
        'Suppression impossible : ce produit possède un historique de '
        'mouvements. Vous pouvez le conserver ou l’archiver plus tard.',
      );
    }
    final count = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    if (count == 0) {
      throw const AppException('Ce produit n’existe plus.');
    }
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
