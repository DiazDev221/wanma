import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../core/errors/app_exception.dart';
import '../data/models/client.dart';
import '../data/models/product.dart';
import '../data/models/stock_movement.dart';
import '../data/repositories/client_repository.dart';

/// Logique métier des mouvements de stock.
///
/// Toutes les opérations qui modifient le stock ET l'historique sont exécutées
/// dans une seule transaction SQLite. En cas d'erreur, rien n'est enregistré.
class InventoryService {
  InventoryService(this._database, this._clientRepository);

  final AppDatabase _database;
  final ClientRepository _clientRepository;

  Future<Product> createProduct({
    required String name,
    String? reference,
    required int unitPrice,
    required double initialQuantity,
    required String unit,
    required double lowStockThreshold,
    String? description,
    DateTime? now,
  }) async {
    _validateProductFields(
      name: name,
      unitPrice: unitPrice,
      unit: unit,
      lowStockThreshold: lowStockThreshold,
    );
    if (!initialQuantity.isFinite || initialQuantity < 0) {
      throw const ValidationException(
        'La quantité initiale ne peut pas être négative.',
      );
    }

    final date = now ?? DateTime.now();
    final db = await _database.database;
    try {
      return await db.transaction((txn) async {
        final cleanedReference = _nullable(reference);
        if (cleanedReference != null) {
          final duplicate = await txn.query(
            'products',
            columns: <String>['id'],
            where: 'reference = ? COLLATE NOCASE',
            whereArgs: <Object?>[cleanedReference],
            limit: 1,
          );
          if (duplicate.isNotEmpty) {
            throw const ValidationException(
              'Cette référence est déjà utilisée par un autre produit.',
            );
          }
        }

        final product = Product(
          name: name.trim(),
          reference: cleanedReference,
          unitPrice: unitPrice,
          quantity: initialQuantity,
          unit: unit.trim(),
          lowStockThreshold: lowStockThreshold,
          description: _nullable(description),
          createdAt: date,
          updatedAt: date,
        );
        final id = await txn.insert('products', product.toMap());
        final created = product.copyWith(id: id);

        // Toute quantité initiale est justifiée par une entrée de stock afin
        // que le stock et l'historique restent cohérents.
        if (initialQuantity > 0) {
          final total = (initialQuantity * unitPrice).round();
          await txn.insert('stock_movements', <String, Object?>{
            'product_id': id,
            'movement_type': MovementType.inbound.dbValue,
            'quantity': initialQuantity,
            'unit_price': unitPrice,
            'total_amount': total,
            'movement_date': date.toIso8601String(),
            'status': MovementStatus.active.dbValue,
            'notes': 'Stock initial',
            'created_at': date.toIso8601String(),
          });
        }
        return created;
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw const ValidationException(
          'Cette référence est déjà utilisée par un autre produit.',
        );
      }
      throw AppException(
        'Impossible d’enregistrer le produit. Veuillez réessayer.',
        cause: error,
      );
    }
  }

  /// Enregistre une entrée de stock et augmente la quantité du produit.
  Future<StockMovement> recordStockIn({
    required int productId,
    required double quantity,
    int? unitPrice,
    String? notes,
    DateTime? date,
  }) async {
    _validateMovementQuantity(quantity);
    _validatePrice(unitPrice);
    final movementDate = date ?? DateTime.now();
    final db = await _database.database;

    return db.transaction((txn) async {
      final productRow = await _findProductRow(txn, productId);
      final appliedPrice =
          unitPrice ?? (productRow['unit_price'] as num).toInt();
      _validatePrice(appliedPrice);
      final total = (quantity * appliedPrice).round();

      final movementId = await txn.insert('stock_movements', <String, Object?>{
        'product_id': productId,
        'movement_type': MovementType.inbound.dbValue,
        'quantity': quantity,
        'unit_price': appliedPrice,
        'total_amount': total,
        'movement_date': movementDate.toIso8601String(),
        'status': MovementStatus.active.dbValue,
        'notes': _nullable(notes),
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.rawUpdate(
        '''
        UPDATE products
        SET quantity = quantity + ?, updated_at = ?
        WHERE id = ?
        ''',
        <Object?>[quantity, DateTime.now().toIso8601String(), productId],
      );

      return StockMovement(
        id: movementId,
        productId: productId,
        movementType: MovementType.inbound,
        quantity: quantity,
        unitPrice: appliedPrice,
        totalAmount: total,
        movementDate: movementDate,
        status: MovementStatus.active,
        notes: _nullable(notes),
        productName: productRow['name'] as String,
        productReference: productRow['reference'] as String?,
        productUnit: productRow['unit'] as String,
      );
    });
  }

  /// Enregistre une sortie. Le client peut être existant ou créé dans la même
  /// transaction, ce qui évite les fiches clients orphelines.
  Future<StockMovement> recordStockOut({
    required int productId,
    required double quantity,
    int? unitPrice,
    String? notes,
    int? clientId,
    Client? newClient,
    bool allowDuplicatePhone = false,
    bool isCredit = false,
    DateTime? date,
  }) async {
    _validateMovementQuantity(quantity);
    _validatePrice(unitPrice);
    if (clientId == null && newClient == null) {
      throw const ValidationException('Veuillez sélectionner un client.');
    }
    if (clientId != null && newClient != null) {
      throw const ValidationException(
        'Sélectionnez un client existant ou créez-en un seul.',
      );
    }

    final movementDate = date ?? DateTime.now();
    final db = await _database.database;

    try {
      return await db.transaction((txn) async {
        final productRow = await _findProductRow(txn, productId);
        final available = (productRow['quantity'] as num).toDouble();
        if (quantity > available) {
          throw StockException(
            'Stock insuffisant : ${_quantityLabel(available)} disponible(s) '
            'seulement pour ce produit.',
          );
        }

        Client resolvedClient;
        if (newClient != null) {
          if (newClient.id != null) {
            throw const ValidationException(
              'Le nouveau client ne doit pas déjà posséder d’identifiant.',
            );
          }
          resolvedClient = await _clientRepository.create(
            newClient,
            allowDuplicatePhone: allowDuplicatePhone,
            executor: txn,
          );
        } else {
          final found = await _clientRepository.findById(
            clientId!,
            executor: txn,
          );
          if (found == null) {
            throw const ValidationException(
              'Le client sélectionné n’existe plus.',
            );
          }
          resolvedClient = found;
        }

        final appliedPrice =
            unitPrice ?? (productRow['unit_price'] as num).toInt();
        _validatePrice(appliedPrice);
        final total = (quantity * appliedPrice).round();
        final nowIso = DateTime.now().toIso8601String();
        final paymentStatus = isCredit
            ? PaymentStatus.credit
            : PaymentStatus.paid;

        final movementId = await txn.insert(
          'stock_movements',
          <String, Object?>{
            'product_id': productId,
            'movement_type': MovementType.outbound.dbValue,
            'quantity': quantity,
            'unit_price': appliedPrice,
            'total_amount': total,
            'movement_date': movementDate.toIso8601String(),
            'status': MovementStatus.active.dbValue,
            'payment_status': paymentStatus.dbValue,
            'sold_on_credit': isCredit ? 1 : 0,
            'paid_at': isCredit ? null : movementDate.toIso8601String(),
            'notes': _nullable(notes),
            'created_at': nowIso,
          },
        );

        await txn.insert('stock_out_details', <String, Object?>{
          'movement_id': movementId,
          'client_id': resolvedClient.id,
        });

        // Mise à jour conditionnelle : la base refuse toute quantité négative,
        // même si deux opérations étaient lancées simultanément.
        final updated = await txn.rawUpdate(
          '''
          UPDATE products
          SET quantity = quantity - ?, updated_at = ?
          WHERE id = ? AND quantity >= ?
          ''',
          <Object?>[quantity, nowIso, productId, quantity],
        );
        if (updated != 1) {
          throw const StockException(
            'Stock insuffisant : la sortie a été annulée.',
          );
        }

        return StockMovement(
          id: movementId,
          productId: productId,
          movementType: MovementType.outbound,
          quantity: quantity,
          unitPrice: appliedPrice,
          totalAmount: total,
          movementDate: movementDate,
          status: MovementStatus.active,
          paymentStatus: paymentStatus,
          soldOnCredit: isCredit,
          paidAt: isCredit ? null : movementDate,
          notes: _nullable(notes),
          productName: productRow['name'] as String,
          productReference: productRow['reference'] as String?,
          productUnit: productRow['unit'] as String,
          clientId: resolvedClient.id,
          clientFirstName: resolvedClient.firstName,
          clientLastName: resolvedClient.lastName,
          clientPhone: resolvedClient.phone,
        );
      });
    } on DatabaseException catch (error) {
      throw AppException(
        'Impossible d’enregistrer la sortie. Aucune donnée n’a été modifiée.',
        cause: error,
      );
    }
  }

  /// Marque une sortie à crédit comme remboursée par le client.
  ///
  /// L'opération reste la même : seul le statut de paiement change, avec la
  /// date du remboursement. Une sortie annulée ou déjà payée est refusée.
  Future<void> markMovementPaid({required int movementId}) async {
    final db = await _database.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final rows = await txn.query(
        'stock_movements',
        columns: <String>['movement_type', 'status', 'payment_status'],
        where: 'id = ?',
        whereArgs: <Object?>[movementId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const AppException('Cette opération n’existe plus.');
      }
      final row = rows.first;
      if (MovementType.fromDb(row['movement_type'] as String) !=
          MovementType.outbound) {
        throw const ValidationException(
          'Seule une sortie de stock peut être marquée comme payée.',
        );
      }
      if (row['status'] == MovementStatus.cancelled.dbValue) {
        throw const AppException(
          'Une opération annulée ne peut pas être marquée comme payée.',
        );
      }
      if (row['payment_status'] == PaymentStatus.paid.dbValue) {
        throw const AppException('Cette sortie est déjà marquée comme payée.');
      }

      final updated = await txn.update(
        'stock_movements',
        <String, Object?>{
          'payment_status': PaymentStatus.paid.dbValue,
          'paid_at': nowIso,
        },
        where:
            'id = ? AND movement_type = ? AND status = ? '
            'AND payment_status = ?',
        whereArgs: <Object?>[
          movementId,
          MovementType.outbound.dbValue,
          MovementStatus.active.dbValue,
          PaymentStatus.credit.dbValue,
        ],
      );
      if (updated != 1) {
        throw const AppException(
          'Le paiement n’a pas pu être enregistré. Réessayez.',
        );
      }
    });
  }

  /// Annule un mouvement sans le supprimer.
  ///
  /// Une sortie annulée réintègre le stock. Une entrée ne peut être annulée
  /// que si le stock actuel permet de retirer la quantité concernée.
  Future<void> cancelMovement({required int movementId, String? reason}) async {
    final db = await _database.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final rows = await txn.query(
        'stock_movements',
        where: 'id = ?',
        whereArgs: <Object?>[movementId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const AppException('Cette opération n’existe plus.');
      }
      final row = rows.first;
      final status = row['status'] as String;
      if (status == MovementStatus.cancelled.dbValue) {
        throw const AppException('Cette opération est déjà annulée.');
      }

      final productId = row['product_id'] as int;
      final quantity = (row['quantity'] as num).toDouble();
      final type = MovementType.fromDb(row['movement_type'] as String);
      final productRow = await _findProductRow(txn, productId);
      final available = (productRow['quantity'] as num).toDouble();

      if (type == MovementType.outbound) {
        await txn.rawUpdate(
          '''
          UPDATE products
          SET quantity = quantity + ?, updated_at = ?
          WHERE id = ?
          ''',
          <Object?>[quantity, now.toIso8601String(), productId],
        );
      } else {
        if (available < quantity) {
          throw StockException(
            'Annulation impossible : le stock actuel '
            '(${_quantityLabel(available)}) est inférieur à la quantité '
            'entrée (${_quantityLabel(quantity)}).',
          );
        }
        await txn.rawUpdate(
          '''
          UPDATE products
          SET quantity = quantity - ?, updated_at = ?
          WHERE id = ? AND quantity >= ?
          ''',
          <Object?>[quantity, now.toIso8601String(), productId, quantity],
        );
      }

      final updated = await txn.update(
        'stock_movements',
        <String, Object?>{
          'status': MovementStatus.cancelled.dbValue,
          'cancelled_at': now.toIso8601String(),
          'cancellation_reason': _nullable(reason) ?? 'Annulation manuelle',
        },
        where: 'id = ? AND status = ?',
        whereArgs: <Object?>[movementId, MovementStatus.active.dbValue],
      );
      if (updated != 1) {
        throw const AppException(
          'L’annulation n’a pas pu être finalisée. Réessayez.',
        );
      }
    });
  }

  Future<Map<String, Object?>> _findProductRow(
    DatabaseExecutor txn,
    int productId,
  ) async {
    final rows = await txn.query(
      'products',
      where: 'id = ?',
      whereArgs: <Object?>[productId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ValidationException('Le produit sélectionné n’existe plus.');
    }
    return rows.first;
  }

  static void _validateProductFields({
    required String name,
    required int unitPrice,
    required String unit,
    required double lowStockThreshold,
  }) {
    if (name.trim().length < 2) {
      throw const ValidationException(
        'Le nom du produit doit contenir au moins 2 caractères.',
      );
    }
    if (unit.trim().isEmpty) {
      throw const ValidationException('Veuillez choisir une unité.');
    }
    _validatePrice(unitPrice);
    if (!lowStockThreshold.isFinite || lowStockThreshold < 0) {
      throw const ValidationException(
        'Le seuil d’alerte ne peut pas être négatif.',
      );
    }
  }

  static void _validateMovementQuantity(double quantity) {
    if (!quantity.isFinite || quantity <= 0) {
      throw const StockException(
        'La quantité doit être strictement supérieure à zéro.',
      );
    }
  }

  static void _validatePrice(int? price) {
    if (price != null && price < 0) {
      throw const ValidationException('Le prix ne peut pas être négatif.');
    }
  }

  static String _quantityLabel(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    return quantity.toStringAsFixed(2).replaceAll('.', ',');
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
