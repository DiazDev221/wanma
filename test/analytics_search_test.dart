import 'package:flutter_test/flutter_test.dart';

import 'package:wanma/core/constants/app_constants.dart';
import 'package:wanma/core/utils/formatters.dart';
import 'package:wanma/core/utils/movement_grouping.dart';
import 'package:wanma/core/utils/search.dart';
import 'package:wanma/data/models/client.dart';
import 'package:wanma/data/models/stock_movement.dart';
import 'package:wanma/services/analytics_service.dart';

import 'support/test_harness.dart';

void main() {
  late TestHarness harness;

  setUpAll(TestHarness.initializeTestDependencies);

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  group('Scénario 12 - Recherche et filtres hors ligne', () {
    test('normalise les accents et la casse', () {
      expect(normalizeForSearch('  Élève Café  '), 'eleve cafe');
      expect(normalizeForSearch('Thé vert'), 'the vert');
      expect(normalizeForSearch('CÔTÉ D’IVOIRE'), 'cote d’ivoire');
    });

    test(
      'recherche produits et clients sans tenir compte des accents',
      () async {
        final appState = await harness.createAppState();
        addTearDown(appState.dispose);

        final tea = await appState.addProduct(
          name: 'Thé vert',
          reference: 'THE-01',
          unitPrice: 500,
          initialQuantity: 2,
          unit: 'Pièce',
          lowStockThreshold: 5,
        );
        await appState.addProduct(
          name: 'Café moulu',
          reference: 'CAF-01',
          unitPrice: 1200,
          initialQuantity: 20,
          unit: 'Kilogramme',
          lowStockThreshold: 3,
        );
        await appState.addClient(
          Client(
            firstName: 'Amadou',
            lastName: 'Ndiaye',
            phone: '77 123 45 67',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
        await appState.addClient(
          Client(
            firstName: 'Fatou',
            lastName: 'Diop',
            phone: '76 987 65 43',
            createdAt: DateTime(2026, 1, 2),
          ),
        );

        expect(appState.searchProducts(query: 'the').single.id, tea.id);
        expect(
          appState.searchProducts(query: 'CAFE').single.name,
          'Café moulu',
        );
        expect(appState.searchProducts(query: 'THE-01'), hasLength(1));
        expect(appState.searchProducts(lowStockOnly: true).single.id, tea.id);
        expect(
          appState.searchProducts(sort: ProductSort.quantityDesc).first.name,
          'Café moulu',
        );

        expect(appState.searchClients('amad').single.fullName, 'Amadou Ndiaye');
        expect(appState.searchClients('771234567').single.firstName, 'Amadou');
        expect(appState.searchClients('diop').single.firstName, 'Fatou');
      },
    );

    test('filtre les mouvements par type, entité et période', () async {
      final appState = await harness.createAppState();
      addTearDown(appState.dispose);

      final product = await appState.addProduct(
        name: 'Riz',
        unitPrice: 1000,
        initialQuantity: 10,
        unit: 'Sac',
        lowStockThreshold: 2,
      );
      final client = await appState.addClient(
        Client(
          firstName: 'Mamadou',
          lastName: 'Fall',
          phone: '78 111 22 33',
          createdAt: DateTime(2026, 3, 1),
        ),
      );
      final oldDate = DateTime(2026, 3, 10, 9);
      final entry = await appState.recordStockIn(
        productId: product.id!,
        quantity: 5,
        date: oldDate,
      );
      final exit = await appState.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
        date: DateTime(2026, 3, 12, 15),
      );
      await appState.cancelMovement(exit.id!, reason: 'Test filtre');

      expect(
        appState.filterMovements(type: MovementType.inbound).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        appState.filterMovements(
          type: MovementType.outbound,
          includeCancelled: false,
        ),
        isEmpty,
      );
      final cancelled = appState.filterMovements(
        type: MovementType.outbound,
        includeCancelled: true,
      );
      expect(cancelled.single.isCancelled, isTrue);
      expect(appState.filterMovements(clientId: client.id).single.id, exit.id);
      expect(
        appState.filterMovements(productId: product.id).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        appState
            .filterMovements(
              from: DateTime(2026, 3, 9),
              to: DateTime(2026, 3, 11),
            )
            .map((movement) => movement.id),
        contains(entry.id),
      );
      expect(appState.filterMovements(query: 'Mamadou'), hasLength(1));
    });
  });

  group('Scénario 13 - Tableau de bord et rapports', () {
    test('calcule les indicateurs et la période demandée', () async {
      final appState = await harness.createAppState();
      addTearDown(appState.dispose);

      final product = await appState.addProduct(
        name: 'Huile',
        reference: 'HUI-01',
        unitPrice: 1500,
        initialQuantity: 10,
        unit: 'Carton',
        lowStockThreshold: 6,
      );
      final client = await appState.addClient(
        Client(
          firstName: 'Aïssatou',
          lastName: 'Sow',
          phone: '77 654 32 10',
          createdAt: DateTime(2026, 3, 1),
        ),
      );

      await appState.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 3,
        date: DateTime.now(),
      );
      final cancelled = await appState.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 1,
        date: DateTime.now(),
      );
      await appState.cancelMovement(cancelled.id!, reason: 'Erreur de caisse');
      await appState.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
        date: DateTime.now().subtract(const Duration(days: 1)),
      );

      final stats = appState.dashboardStats;
      expect(stats.productCount, 1);
      expect(stats.clientCount, 1);
      expect(stats.movementCount, 4);
      expect(stats.totalQuantity, 5);
      expect(stats.stockValue, 7500);
      expect(stats.todayEntryCount, 1);
      expect(stats.todayExitCount, 1);
      expect(stats.lowStockProducts.single.id, product.id);

      final today = appState.todayReport();
      expect(today.activeEntries, 1);
      expect(today.activeExits, 1);
      expect(today.entryQuantity, 10);
      expect(today.exitQuantity, 3);
      expect(today.entryAmount, 15000);
      expect(today.exitAmount, 4500);
      expect(today.cancelledCount, 1);
      expect(today.topProducts.single.product.id, product.id);
      expect(today.topProducts.single.quantityOut, 3);
      expect(today.topProducts.single.amountOut, 4500);
      expect(today.clientLines.single.clientName, 'Aïssatou Sow');
      expect(today.clientLines.single.movementCount, 1);
      expect(today.stockValue, 7500);

      final month = appState.buildReport(AnalyticsService.periodForMonth());
      expect(
        month.movements.where((m) => m.movementType == MovementType.outbound),
        hasLength(3),
      );
      expect(month.cancelledCount, 1);
      expect(month.activeExits, 2);
    });

    test('suit les crédits à recouvrer et leur règlement', () async {
      final appState = await harness.createAppState();
      addTearDown(appState.dispose);

      final product = await appState.addProduct(
        name: 'Sucre',
        unitPrice: 1000,
        initialQuantity: 10,
        unit: 'Sac',
        lowStockThreshold: 2,
      );
      final client = await appState.addClient(
        Client(
          firstName: 'Fatou',
          lastName: 'Ba',
          phone: '76 222 33 44',
          createdAt: DateTime(2026, 3, 1),
        ),
      );
      final credit = await appState.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
        isCredit: true,
      );

      expect(credit.paymentStatus, PaymentStatus.credit);
      expect(appState.outstandingCreditCount, 1);
      expect(appState.outstandingCreditAmount, 2000);
      expect(appState.outstandingCreditForClient(client.id!), 2000);
      expect(appState.pendingCreditsForClient(client.id!), hasLength(1));
      expect(appState.filterMovements(unpaidCreditOnly: true), hasLength(1));

      final report = appState.todayReport();
      expect(report.creditAmount, 2000);
      expect(report.unpaidCreditAmount, 2000);
      expect(report.clientLines.single.creditAmount, 2000);

      await appState.markMovementPaid(credit.id!);

      expect(appState.outstandingCreditCount, 0);
      expect(appState.outstandingCreditAmount, 0);
      expect(appState.pendingCreditsForClient(client.id!), isEmpty);
      expect(appState.filterMovements(unpaidCreditOnly: true), isEmpty);
      final afterPayment = appState.todayReport();
      expect(afterPayment.creditAmount, 2000);
      expect(afterPayment.unpaidCreditAmount, 0);
    });
  });

  group('Regroupement des opérations par date', () {
    StockMovement movement(int id, DateTime date) {
      return StockMovement(
        id: id,
        productId: 1,
        movementType: MovementType.outbound,
        quantity: 1,
        unitPrice: 1000,
        totalAmount: 1000,
        movementDate: date,
        status: MovementStatus.active,
      );
    }

    test('regroupe les journées et trie du plus récent au plus ancien', () {
      final groups = groupMovementsByDay(<StockMovement>[
        movement(3, DateTime(2026, 3, 1, 10)),
        movement(1, DateTime(2026, 3, 2, 18)),
        movement(2, DateTime(2026, 3, 2, 9)),
        movement(4, DateTime(2026, 3, 2, 18)),
      ]);

      expect(groups, hasLength(2));
      expect(groups.first.date, DateTime(2026, 3, 2));
      expect(groups.first.movements.map((movement) => movement.id), <int?>[
        4,
        1,
        2,
      ]);
      expect(groups.last.date, DateTime(2026, 3, 1));
      expect(groups.last.movements.single.id, 3);
    });

    test('nomme aujourd’hui, hier puis la date complète', () {
      final now = DateTime(2026, 3, 3, 15);
      expect(
        AppFormatters.dayLabel(DateTime(2026, 3, 3, 8), now: now),
        'Aujourd’hui',
      );
      expect(
        AppFormatters.dayLabel(DateTime(2026, 3, 2, 23), now: now),
        'Hier',
      );
      expect(
        AppFormatters.dayLabel(DateTime(2026, 3, 1), now: now),
        contains('1 mars 2026'),
      );
    });
  });
}
