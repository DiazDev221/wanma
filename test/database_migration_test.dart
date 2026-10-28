import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wanma/core/constants/app_constants.dart';
import 'package:wanma/core/database/app_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wanma_migration_');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('migre une base v1 vers le schéma courant', () async {
    final path = p.join(directory.path, 'v1.db');
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE stock_movements (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER NOT NULL,
              movement_type TEXT NOT NULL,
              quantity REAL NOT NULL,
              unit_price INTEGER NOT NULL,
              total_amount INTEGER NOT NULL,
              movement_date TEXT NOT NULL,
              status TEXT NOT NULL,
              notes TEXT,
              cancelled_at TEXT,
              cancellation_reason TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.insert('stock_movements', <String, Object?>{
            'product_id': 1,
            'movement_type': 'OUT',
            'quantity': 2,
            'unit_price': 1000,
            'total_amount': 2000,
            'movement_date': '2026-03-01T10:00:00.000',
            'status': 'ACTIVE',
            'created_at': '2026-03-01T10:00:00.000',
          });
        },
      ),
    );
    await legacy.close();

    final appDatabase = AppDatabase(factory: databaseFactoryFfi, path: path);
    final db = await appDatabase.database;

    final columns = await db.rawQuery('PRAGMA table_info(stock_movements)');
    final names = columns.map((column) => column['name']).toSet();
    expect(
      names,
      containsAll(<String>['payment_status', 'paid_at', 'sold_on_credit']),
    );

    final row = (await db.query('stock_movements')).single;
    expect(row['payment_status'], 'PAID');
    expect(row['paid_at'], isNull);
    expect(row['sold_on_credit'], 0);
    expect(
      (await db.rawQuery('PRAGMA user_version')).single.values.first,
      AppConstants.databaseVersion,
    );

    await appDatabase.close();
  });

  test(
    'conserve les ventes à crédit lors de la migration v2 vers v3',
    () async {
      final path = p.join(directory.path, 'v2.db');
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE stock_movements (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER NOT NULL,
              movement_type TEXT NOT NULL,
              quantity REAL NOT NULL,
              unit_price INTEGER NOT NULL,
              total_amount INTEGER NOT NULL,
              movement_date TEXT NOT NULL,
              status TEXT NOT NULL,
              payment_status TEXT NOT NULL DEFAULT 'PAID',
              paid_at TEXT,
              notes TEXT,
              cancelled_at TEXT,
              cancellation_reason TEXT,
              created_at TEXT NOT NULL
            )
          ''');
            await db.insert('stock_movements', <String, Object?>{
              'id': 1,
              'product_id': 1,
              'movement_type': 'OUT',
              'quantity': 1,
              'unit_price': 1000,
              'total_amount': 1000,
              'movement_date': '2026-03-01T10:00:00.000',
              'status': 'ACTIVE',
              'payment_status': 'PAID',
              'paid_at': '2026-03-01T10:00:00.000',
              'created_at': '2026-03-01T10:00:00.000',
            });
            await db.insert('stock_movements', <String, Object?>{
              'id': 2,
              'product_id': 1,
              'movement_type': 'OUT',
              'quantity': 2,
              'unit_price': 1000,
              'total_amount': 2000,
              'movement_date': '2026-03-01T11:00:00.000',
              'status': 'ACTIVE',
              'payment_status': 'CREDIT',
              'created_at': '2026-03-01T11:00:00.000',
            });
            await db.insert('stock_movements', <String, Object?>{
              'id': 3,
              'product_id': 1,
              'movement_type': 'OUT',
              'quantity': 3,
              'unit_price': 1000,
              'total_amount': 3000,
              'movement_date': '2026-03-01T12:00:00.000',
              'status': 'ACTIVE',
              'payment_status': 'PAID',
              'paid_at': '2026-03-05T09:00:00.000',
              'created_at': '2026-03-01T12:00:00.000',
            });
          },
        ),
      );
      await legacy.close();

      final appDatabase = AppDatabase(factory: databaseFactoryFfi, path: path);
      final db = await appDatabase.database;

      final rows = await db.query('stock_movements', orderBy: 'id');
      expect(rows.map((row) => row['sold_on_credit']), <Object?>[0, 1, 1]);

      await appDatabase.close();
    },
  );
}
