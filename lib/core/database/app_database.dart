import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';

/// Accès centralisé à la base SQLite locale Wanma.
///
/// Une seule connexion est conservée pendant la vie de l'application. Des
/// paramètres d'injection permettent d'utiliser une base en mémoire dans les
/// tests sans modifier le code de production.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _customPath = path;

  static final AppDatabase instance = AppDatabase();

  final DatabaseFactory _factory;
  final String? _customPath;

  Database? _database;
  String? _resolvedPath;

  bool get isOpen => _database?.isOpen ?? false;
  String? get path => _resolvedPath ?? _database?.path;
  DatabaseFactory get factory => _factory;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    return _open();
  }

  Future<Database> _open() async {
    final path = await _resolvePath();
    final db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppConstants.databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: _onDowngrade,
      ),
    );
    _database = db;
    _resolvedPath = path;
    return db;
  }

  Future<String> _resolvePath() async {
    final custom = _customPath;
    if (custom != null) return custom;
    final base = await _factory.getDatabasesPath();
    return p.join(base, AppConstants.databaseName);
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK(length(trim(name)) > 0),
        reference TEXT,
        unit_price INTEGER NOT NULL CHECK(unit_price >= 0),
        quantity REAL NOT NULL DEFAULT 0 CHECK(quantity >= 0),
        unit TEXT NOT NULL CHECK(length(trim(unit)) > 0),
        low_stock_threshold REAL NOT NULL DEFAULT 5
          CHECK(low_stock_threshold >= 0),
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL CHECK(length(trim(first_name)) > 0),
        last_name TEXT NOT NULL CHECK(length(trim(last_name)) > 0),
        phone TEXT NOT NULL CHECK(length(trim(phone)) > 0),
        phone_normalized TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        movement_type TEXT NOT NULL
          CHECK(movement_type IN ('IN', 'OUT')),
        quantity REAL NOT NULL CHECK(quantity > 0),
        unit_price INTEGER NOT NULL CHECK(unit_price >= 0),
        total_amount INTEGER NOT NULL CHECK(total_amount >= 0),
        movement_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'ACTIVE'
          CHECK(status IN ('ACTIVE', 'CANCELLED')),
        payment_status TEXT NOT NULL DEFAULT 'PAID'
          CHECK(payment_status IN ('PAID', 'CREDIT')),
        sold_on_credit INTEGER NOT NULL DEFAULT 0
          CHECK(sold_on_credit IN (0, 1)),
        paid_at TEXT,
        notes TEXT,
        cancelled_at TEXT,
        cancellation_reason TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      )
    ''');

    batch.execute('''
      CREATE TABLE stock_out_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        movement_id INTEGER NOT NULL UNIQUE,
        client_id INTEGER NOT NULL,
        FOREIGN KEY (movement_id) REFERENCES stock_movements(id)
          ON DELETE RESTRICT,
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_products_name ON products(name COLLATE NOCASE)',
    );
    batch.execute(
      'CREATE INDEX idx_products_reference ON products(reference COLLATE NOCASE)',
    );
    batch.execute('''
      CREATE UNIQUE INDEX idx_products_unique_reference
      ON products(reference COLLATE NOCASE)
      WHERE reference IS NOT NULL AND trim(reference) <> ''
    ''');
    batch.execute(
      'CREATE INDEX idx_products_low_stock ON products(quantity, low_stock_threshold)',
    );
    batch.execute(
      'CREATE INDEX idx_clients_name ON clients(last_name COLLATE NOCASE, first_name COLLATE NOCASE)',
    );
    batch.execute(
      'CREATE INDEX idx_clients_phone ON clients(phone_normalized)',
    );
    batch.execute(
      'CREATE INDEX idx_movements_product ON stock_movements(product_id)',
    );
    batch.execute(
      'CREATE INDEX idx_movements_date ON stock_movements(movement_date DESC)',
    );
    batch.execute(
      'CREATE INDEX idx_movements_type ON stock_movements(movement_type)',
    );
    batch.execute(
      'CREATE INDEX idx_movements_status ON stock_movements(status)',
    );
    batch.execute(
      'CREATE INDEX idx_movements_payment ON stock_movements(payment_status)',
    );
    batch.execute(
      'CREATE INDEX idx_out_details_client ON stock_out_details(client_id)',
    );
    batch.execute(
      'CREATE INDEX idx_out_details_movement ON stock_out_details(movement_id)',
    );

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Chaque incrément de version ajoute une étape idempotente ici. Les
    // données existantes sont conservées.
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 2:
          // Suivi des ventes à crédit. Les mouvements existants étaient
          // considérés comme réglés au comptant.
          await db.execute('''
            ALTER TABLE stock_movements
            ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'PAID'
              CHECK(payment_status IN ('PAID', 'CREDIT'))
          ''');
          await db.execute(
            'ALTER TABLE stock_movements ADD COLUMN paid_at TEXT',
          );
          await db.execute(
            'CREATE INDEX idx_movements_payment '
            'ON stock_movements(payment_status)',
          );
          break;
        case 3:
          // Conserve l'origine « vente à crédit » même après règlement, afin
          // que les rapports continuent de compter la vente à crédit.
          await db.execute('''
            ALTER TABLE stock_movements
            ADD COLUMN sold_on_credit INTEGER NOT NULL DEFAULT 0
              CHECK(sold_on_credit IN (0, 1))
          ''');
          await db.execute('''
            UPDATE stock_movements
            SET sold_on_credit = 1
            WHERE movement_type = 'OUT'
              AND (
                payment_status = 'CREDIT'
                OR (paid_at IS NOT NULL AND paid_at <> movement_date)
              )
          ''');
          break;
        default:
          break;
      }
    }
  }

  static Future<void> _onDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw StateError(
      'Cette version de Wanma ne peut pas ouvrir une base plus récente '
      '(base v$oldVersion, application v$newVersion).',
    );
  }

  /// Ferme la connexion courante, notamment pour restaurer une sauvegarde.
  Future<void> close() async {
    final current = _database;
    _database = null;
    if (current != null && current.isOpen) {
      await current.close();
    }
  }

  /// Rouvre la base après une restauration.
  Future<Database> reopen() async {
    await close();
    return database;
  }

  /// Exécute un checkpoint WAL avant la copie de la base.
  Future<void> checkpoint() async {
    final db = await database;
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {
      // Le checkpoint est un confort : les bases en mode journal classique
      // n'exposent pas toujours ce pragma. La copie reste valide.
    }
  }

  /// Crée une copie SQL cohérente de la base dans [destination].
  Future<void> createConsistentCopy(String destination) async {
    final db = await database;
    final escaped = destination.replaceAll("'", "''");
    await db.execute("VACUUM INTO '$escaped'");
  }
}
