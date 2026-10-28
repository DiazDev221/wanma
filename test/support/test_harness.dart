import 'dart:io';

import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wanma/core/database/app_database.dart';
import 'package:wanma/data/models/client.dart';
import 'package:wanma/data/models/product.dart';
import 'package:wanma/data/models/stock_movement.dart';
import 'package:wanma/data/repositories/client_repository.dart';
import 'package:wanma/data/repositories/movement_repository.dart';
import 'package:wanma/data/repositories/product_repository.dart';
import 'package:wanma/services/backup_service.dart';
import 'package:wanma/services/export_service.dart';
import 'package:wanma/services/inventory_service.dart';
import 'package:wanma/services/security_service.dart';
import 'package:wanma/state/app_state.dart';

/// Prépare une base SQLite FFI isolée pour un test.
class TestHarness {
  TestHarness._({
    required this.directory,
    required this.database,
    required this.productRepository,
    required this.clientRepository,
    required this.movementRepository,
    required this.inventoryService,
    required this.securityService,
    required this.backupService,
  });

  final Directory directory;
  final AppDatabase database;
  final ProductRepository productRepository;
  final ClientRepository clientRepository;
  final MovementRepository movementRepository;
  final InventoryService inventoryService;
  final SecurityService securityService;
  final BackupService backupService;
  final ExportService exportService = const ExportService();

  static Future<void> initializeTestDependencies() async {
    sqfliteFfiInit();
    await initializeDateFormatting('fr_FR');
  }

  static Future<TestHarness> create({
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final directory = await Directory.systemTemp.createTemp('wanma_test_');
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'wanma.db'),
    );
    final clientRepository = ClientRepository(database);
    return TestHarness._(
      directory: directory,
      database: database,
      productRepository: ProductRepository(database),
      clientRepository: clientRepository,
      movementRepository: MovementRepository(database),
      inventoryService: InventoryService(database, clientRepository),
      securityService: SecurityService(),
      backupService: BackupService(database),
    );
  }

  Future<Product> createProduct({
    String name = 'Riz',
    String? reference,
    int unitPrice = 1000,
    double initialQuantity = 10,
    String unit = 'Sac',
    double lowStockThreshold = 5,
    String? description,
  }) {
    return inventoryService.createProduct(
      name: name,
      reference: reference,
      unitPrice: unitPrice,
      initialQuantity: initialQuantity,
      unit: unit,
      lowStockThreshold: lowStockThreshold,
      description: description,
    );
  }

  Future<Client> createClient({
    String firstName = 'Amadou',
    String lastName = 'Ndiaye',
    String phone = '77 123 45 67',
    bool allowDuplicatePhone = false,
  }) {
    return clientRepository.create(
      Client(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        createdAt: DateTime(2026, 1, 15, 9),
      ),
      allowDuplicatePhone: allowDuplicatePhone,
    );
  }

  Future<AppState> createAppState({Duration splash = Duration.zero}) async {
    final state = AppState(
      productRepository: productRepository,
      clientRepository: clientRepository,
      movementRepository: movementRepository,
      inventoryService: inventoryService,
      securityService: securityService,
      backupService: backupService,
      minimumSplashDuration: splash,
    );
    await state.initialize();
    return state;
  }

  Future<Product> currentProduct(int id) async {
    final product = await productRepository.findById(id);
    if (product == null) throw StateError('Produit introuvable : $id');
    return product;
  }

  Future<List<StockMovement>> movementsForProduct(int productId) {
    return movementRepository.getForProduct(productId);
  }

  Future<void> dispose() async {
    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
