import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/constants/app_constants.dart';
import '../core/database/app_database.dart';
import '../core/utils/formatters.dart';
import '../core/utils/search.dart';
import '../data/models/client.dart';
import '../data/models/dashboard_stats.dart';
import '../data/models/product.dart';
import '../data/models/report_data.dart';
import '../data/models/stock_movement.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/movement_repository.dart';
import '../data/repositories/product_repository.dart';
import '../services/analytics_service.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../services/inventory_service.dart';
import '../services/security_service.dart';

// Le constructeur expose des noms publics lisibles tout en conservant des
// champs privés pour l'encapsulation.
// ignore_for_file: prefer_initializing_formals

/// État central de Wanma : données locales, préférences de verrouillage et
/// orchestration des services. L'interface écoute ce ChangeNotifier.
class AppState extends ChangeNotifier {
  AppState({
    required ProductRepository productRepository,
    required ClientRepository clientRepository,
    required MovementRepository movementRepository,
    required InventoryService inventoryService,
    required SecurityService securityService,
    required BackupService backupService,
    this.exportService = const ExportService(),
    this.minimumSplashDuration = const Duration(milliseconds: 1100),
  }) : _productRepository = productRepository,
       _clientRepository = clientRepository,
       _movementRepository = movementRepository,
       _inventoryService = inventoryService,
       _securityService = securityService,
       _backupService = backupService;

  factory AppState.production({String? databasePath}) {
    final database = databasePath == null
        ? AppDatabase.instance
        : AppDatabase(path: databasePath);
    final clientRepository = ClientRepository(database);
    return AppState(
      productRepository: ProductRepository(database),
      clientRepository: clientRepository,
      movementRepository: MovementRepository(database),
      inventoryService: InventoryService(database, clientRepository),
      securityService: SecurityService(),
      backupService: BackupService(database),
    );
  }

  final ProductRepository _productRepository;
  final ClientRepository _clientRepository;
  final MovementRepository _movementRepository;
  final InventoryService _inventoryService;
  final SecurityService _securityService;
  final BackupService _backupService;
  final ExportService exportService;
  final Duration minimumSplashDuration;

  List<Product> _products = <Product>[];
  List<Client> _clients = <Client>[];
  List<StockMovement> _movements = <StockMovement>[];

  bool _isInitializing = true;
  bool _initialized = false;
  bool _initializationInProgress = false;
  String? _fatalErrorMessage;
  bool _pinEnabled = false;
  bool _isLocked = false;
  bool _disposed = false;
  Timer? _autoLockTimer;

  List<Product> get products => List<Product>.unmodifiable(_products);
  List<Client> get clients => List<Client>.unmodifiable(_clients);
  List<StockMovement> get movements =>
      List<StockMovement>.unmodifiable(_movements);
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _initialized;
  String? get fatalErrorMessage => _fatalErrorMessage;
  bool get pinEnabled => _pinEnabled;
  bool get isLocked => _isLocked;
  int get lowStockCount => _products.where((p) => p.isLowStock).length;

  Future<void> initialize() async {
    if (_initializationInProgress || _initialized) return;
    _initializationInProgress = true;
    _isInitializing = true;
    _fatalErrorMessage = null;
    _safeNotify();

    final startedAt = DateTime.now();
    try {
      await Future.wait(<Future<void>>[
        _securityService.initialize(),
        _loadData(),
      ]);
      _pinEnabled = _securityService.pinEnabled;
      _isLocked = _pinEnabled;
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minimumSplashDuration) {
        await Future<void>.delayed(minimumSplashDuration - elapsed);
      }
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Erreur d’initialisation Wanma : $error\n$stackTrace');
      _fatalErrorMessage =
          'Impossible de préparer la base de données locale. '
          'Fermez puis rouvrez l’application, ou réessayez.';
    } finally {
      _isInitializing = false;
      _initializationInProgress = false;
      _safeNotify();
    }
  }

  Future<void> retryInitialization() async {
    if (_initializationInProgress) return;
    _initialized = false;
    await initialize();
  }

  Future<void> _loadData() async {
    _products = await _productRepository.getAll();
    _clients = await _clientRepository.getAll();
    _movements = await _movementRepository.getAll();
  }

  Future<void> refreshData() async {
    await _loadData();
    _safeNotify();
  }

  // ---------------------------------------------------------------------------
  // Produits
  // ---------------------------------------------------------------------------

  Future<Product> addProduct({
    required String name,
    String? reference,
    required int unitPrice,
    required double initialQuantity,
    required String unit,
    required double lowStockThreshold,
    String? description,
  }) async {
    final product = await _inventoryService.createProduct(
      name: name,
      reference: reference,
      unitPrice: unitPrice,
      initialQuantity: initialQuantity,
      unit: unit,
      lowStockThreshold: lowStockThreshold,
      description: description,
    );
    await refreshData();
    return product;
  }

  Future<void> updateProduct(Product product) async {
    await _productRepository.update(product);
    await refreshData();
  }

  Future<void> deleteProduct(int productId) async {
    await _productRepository.delete(productId);
    await refreshData();
  }

  Product? productById(int id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  List<Product> searchProducts({
    String query = '',
    ProductSort sort = ProductSort.name,
    bool lowStockOnly = false,
  }) {
    final normalizedQuery = normalizeForSearch(query);
    final filtered = _products
        .where((product) {
          if (lowStockOnly && !product.isLowStock) return false;
          if (normalizedQuery.isEmpty) return true;
          final haystack = normalizeForSearch(
            <String?>[
              product.name,
              product.reference,
              product.unit,
              product.description,
            ].whereType<String>().join(' '),
          );
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: true);

    filtered.sort((a, b) {
      switch (sort) {
        case ProductSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case ProductSort.quantityAsc:
          return a.quantity.compareTo(b.quantity);
        case ProductSort.quantityDesc:
          return b.quantity.compareTo(a.quantity);
        case ProductSort.priceAsc:
          return a.unitPrice.compareTo(b.unitPrice);
        case ProductSort.priceDesc:
          return b.unitPrice.compareTo(a.unitPrice);
        case ProductSort.recent:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return List<Product>.unmodifiable(filtered);
  }

  // ---------------------------------------------------------------------------
  // Clients
  // ---------------------------------------------------------------------------

  Future<Client> addClient(
    Client client, {
    bool allowDuplicatePhone = false,
  }) async {
    final created = await _clientRepository.create(
      client,
      allowDuplicatePhone: allowDuplicatePhone,
    );
    await refreshData();
    return created;
  }

  Future<void> updateClient(
    Client client, {
    bool allowDuplicatePhone = false,
  }) async {
    await _clientRepository.update(
      client,
      allowDuplicatePhone: allowDuplicatePhone,
    );
    await refreshData();
  }

  Future<void> deleteClient(int clientId) async {
    await _clientRepository.delete(clientId);
    await refreshData();
  }

  Client? clientById(int id) {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  Future<Client?> findClientByPhone(String phone) =>
      _clientRepository.findByPhone(phone);

  List<Client> searchClients(String query) {
    final normalizedQuery = normalizeForSearch(query);
    final filtered = _clients
        .where((client) {
          if (normalizedQuery.isEmpty) return true;
          final haystack = normalizeForSearch(
            '${client.firstName} ${client.lastName} ${client.phone} '
            '${client.normalizedPhone}',
          );
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: true);
    filtered.sort((a, b) {
      final byLast = a.lastName.toLowerCase().compareTo(
        b.lastName.toLowerCase(),
      );
      return byLast != 0
          ? byLast
          : a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
    });
    return List<Client>.unmodifiable(filtered);
  }

  // ---------------------------------------------------------------------------
  // Mouvements
  // ---------------------------------------------------------------------------

  Future<StockMovement> recordStockIn({
    required int productId,
    required double quantity,
    int? unitPrice,
    String? notes,
    DateTime? date,
  }) async {
    final movement = await _inventoryService.recordStockIn(
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      notes: notes,
      date: date,
    );
    await refreshData();
    return movement;
  }

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
    final movement = await _inventoryService.recordStockOut(
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      notes: notes,
      clientId: clientId,
      newClient: newClient,
      allowDuplicatePhone: allowDuplicatePhone,
      isCredit: isCredit,
      date: date,
    );
    await refreshData();
    return movement;
  }

  Future<void> markMovementPaid(int movementId) async {
    await _inventoryService.markMovementPaid(movementId: movementId);
    await refreshData();
  }

  Future<void> cancelMovement(int movementId, {String? reason}) async {
    await _inventoryService.cancelMovement(
      movementId: movementId,
      reason: reason,
    );
    await refreshData();
  }

  StockMovement? movementById(int id) {
    for (final movement in _movements) {
      if (movement.id == id) return movement;
    }
    return null;
  }

  List<StockMovement> movementsForProduct(int productId) {
    return List<StockMovement>.unmodifiable(
      _movements.where((movement) => movement.productId == productId),
    );
  }

  List<StockMovement> movementsForClient(int clientId) {
    return List<StockMovement>.unmodifiable(
      _movements.where(
        (movement) => movement.isExit && movement.clientId == clientId,
      ),
    );
  }

  /// Sorties à crédit encore dues, toutes clients confondus.
  List<StockMovement> get pendingCreditMovements =>
      List<StockMovement>.unmodifiable(
        _movements.where((movement) => movement.isCreditPending),
      );

  int get outstandingCreditAmount => pendingCreditMovements.fold<int>(
    0,
    (sum, movement) => sum + movement.totalAmount,
  );

  int get outstandingCreditCount => pendingCreditMovements.length;

  List<StockMovement> pendingCreditsForClient(int clientId) {
    return List<StockMovement>.unmodifiable(
      _movements.where(
        (movement) => movement.isCreditPending && movement.clientId == clientId,
      ),
    );
  }

  int outstandingCreditForClient(int clientId) {
    return pendingCreditsForClient(clientId)
        .fold<int>(0, (sum, movement) => sum + movement.totalAmount);
  }

  List<StockMovement> filterMovements({
    String query = '',
    MovementType? type,
    bool includeCancelled = true,
    bool unpaidCreditOnly = false,
    int? productId,
    int? clientId,
    DateTime? from,
    DateTime? to,
  }) {
    final normalizedQuery = normalizeForSearch(query);
    return List<StockMovement>.unmodifiable(
      _movements.where((movement) {
        if (type != null && movement.movementType != type) return false;
        if (!includeCancelled && movement.isCancelled) return false;
        if (unpaidCreditOnly && !movement.isCreditPending) return false;
        if (productId != null && movement.productId != productId) return false;
        if (clientId != null && movement.clientId != clientId) return false;
        if (from != null && movement.movementDate.isBefore(from)) return false;
        if (to != null && !movement.movementDate.isBefore(to)) return false;
        if (normalizedQuery.isEmpty) return true;
        final haystack = normalizeForSearch(
          <String?>[
            movement.productName,
            movement.productReference,
            movement.clientFullName,
            movement.clientPhone,
            movement.notes,
            movement.cancellationReason,
            movement.movementType.label,
            movement.status.label,
            movement.paymentStatus.label,
            AppFormatters.dateTime(movement.movementDate),
          ].whereType<String>().join(' '),
        );
        return haystack.contains(normalizedQuery);
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Statistiques et rapports
  // ---------------------------------------------------------------------------

  DashboardStats get dashboardStats => AnalyticsService.dashboard(
    products: _products,
    clients: _clients,
    movements: _movements,
  );

  ReportData buildReport(ReportPeriod period) => AnalyticsService.buildReport(
    period: period,
    products: _products,
    movements: _movements,
  );

  ReportData todayReport() => buildReport(AnalyticsService.periodForToday());

  // ---------------------------------------------------------------------------
  // Sécurité et verrouillage
  // ---------------------------------------------------------------------------

  Future<bool> unlock(String pin) async {
    if (!_pinEnabled) {
      _isLocked = false;
      _safeNotify();
      return true;
    }
    final valid = await _securityService.verifyPin(pin);
    if (valid) {
      _isLocked = false;
      _safeNotify();
    }
    return valid;
  }

  void lock() {
    if (!_pinEnabled || _isLocked) return;
    _isLocked = true;
    _safeNotify();
  }

  Future<void> enablePin(String pin) async {
    await _securityService.setPin(pin);
    _pinEnabled = true;
    _isLocked = false;
    _safeNotify();
  }

  Future<bool> disablePin(String currentPin) async {
    final valid = await _securityService.verifyPin(currentPin);
    if (!valid) return false;
    await _securityService.disablePin();
    _pinEnabled = false;
    _isLocked = false;
    _safeNotify();
    return true;
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final valid = await _securityService.verifyPin(currentPin);
    if (!valid) return false;
    await _securityService.setPin(newPin);
    _pinEnabled = true;
    _isLocked = false;
    _safeNotify();
    return true;
  }

  /// Verrouille automatiquement l'application après un passage en arrière-plan
  /// prolongé, sans gêner le sélecteur de fichiers d'une opération rapide.
  void handleLifecycleState(AppLifecycleState state) {
    if (!_pinEnabled) return;
    if (state == AppLifecycleState.resumed) {
      _autoLockTimer?.cancel();
      _autoLockTimer = null;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _autoLockTimer?.cancel();
      _autoLockTimer = Timer(const Duration(seconds: 15), lock);
    } else if (state == AppLifecycleState.detached) {
      lock();
    }
  }

  // ---------------------------------------------------------------------------
  // Sauvegarde et restauration
  // ---------------------------------------------------------------------------

  Future<BackupFile> createBackup() => _backupService.createBackup();

  Future<BackupInfo> validateBackup(Uint8List bytes) =>
      _backupService.validateBackup(bytes);

  Future<BackupInfo> restoreBackup(Uint8List bytes) async {
    final info = await _backupService.restoreBackup(bytes);
    await _loadData();
    _safeNotify();
    return info;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoLockTimer?.cancel();
    super.dispose();
  }
}
