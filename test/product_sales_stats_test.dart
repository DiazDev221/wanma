import 'package:flutter_test/flutter_test.dart';

import 'package:wanma/data/models/client.dart';
import 'package:wanma/data/models/stock_movement.dart';
import 'package:wanma/services/analytics_service.dart';

import 'support/test_harness.dart';

void main() {
  setUpAll(TestHarness.initializeTestDependencies);

  group('Encaissements et crédits par produit', () {
    test('compte un crédit réglé à sa date de règlement', () {
      final movements = <StockMovement>[
        StockMovement(
          id: 1,
          productId: 7,
          movementType: MovementType.outbound,
          quantity: 2,
          unitPrice: 1500,
          totalAmount: 3000,
          movementDate: DateTime(2026, 3, 4, 10),
          status: MovementStatus.active,
          paymentStatus: PaymentStatus.paid,
          soldOnCredit: true,
          paidAt: DateTime(2026, 3, 18, 16),
        ),
        StockMovement(
          id: 2,
          productId: 7,
          movementType: MovementType.outbound,
          quantity: 1,
          unitPrice: 2000,
          totalAmount: 2000,
          movementDate: DateTime(2026, 3, 20, 9),
          status: MovementStatus.active,
          paymentStatus: PaymentStatus.paid,
          paidAt: DateTime(2026, 3, 20, 9),
        ),
        StockMovement(
          id: 3,
          productId: 7,
          movementType: MovementType.outbound,
          quantity: 1,
          unitPrice: 2000,
          totalAmount: 2000,
          movementDate: DateTime(2026, 3, 21, 9),
          status: MovementStatus.active,
          paymentStatus: PaymentStatus.credit,
          soldOnCredit: true,
        ),
        StockMovement(
          id: 4,
          productId: 7,
          movementType: MovementType.outbound,
          quantity: 1,
          unitPrice: 2000,
          totalAmount: 2000,
          movementDate: DateTime(2026, 3, 22, 9),
          status: MovementStatus.cancelled,
          paymentStatus: PaymentStatus.credit,
          soldOnCredit: true,
        ),
        StockMovement(
          id: 5,
          productId: 8,
          movementType: MovementType.outbound,
          quantity: 1,
          unitPrice: 2000,
          totalAmount: 2000,
          movementDate: DateTime(2026, 3, 23, 9),
          status: MovementStatus.active,
          paymentStatus: PaymentStatus.paid,
          paidAt: DateTime(2026, 3, 23, 9),
        ),
      ];
      final period = AnalyticsService.customPeriod(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );

      final stats = AnalyticsService.productSalesStats(
        productId: 7,
        movements: movements,
        period: period,
      );

      expect(stats.collectedAmount, 5000);
      expect(stats.collectionCount, 2);
      expect(stats.creditAmount, 5000);
      expect(stats.creditCount, 2);
      expect(stats.unpaidCreditAmount, 2000);
      expect(stats.outstandingCreditAmount, 2000);
      expect(stats.outstandingCreditCount, 1);
      expect(stats.saleCount, 3);
    });

    test('suit les encaissements et le règlement depuis la base', () async {
      final harness = await TestHarness.create();
      addTearDown(harness.dispose);
      final appState = await harness.createAppState();
      addTearDown(appState.dispose);

      final product = await appState.addProduct(
        name: 'Café',
        unitPrice: 1000,
        initialQuantity: 10,
        unit: 'Sac',
        lowStockThreshold: 2,
      );
      final client = await appState.addClient(
        Client(
          firstName: 'Awa',
          lastName: 'Diop',
          phone: '77 555 44 33',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final period = AnalyticsService.customPeriod(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );

      await appState.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
        date: DateTime(2026, 3, 10, 9),
      );
      final credit = await appState.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 3,
        isCredit: true,
        date: DateTime(2026, 3, 11, 9),
      );

      final stats = appState.productSalesStats(product.id!, period);
      expect(stats.collectedAmount, 2000);
      expect(stats.collectionCount, 1);
      expect(stats.creditAmount, 3000);
      expect(stats.creditCount, 1);
      expect(stats.unpaidCreditAmount, 3000);
      expect(stats.outstandingCreditAmount, 3000);
      expect(stats.outstandingCreditCount, 1);
      expect(stats.saleCount, 2);

      await appState.markMovementPaid(credit.id!);

      final afterPayment = appState.productSalesStats(product.id!, period);
      expect(afterPayment.collectedAmount, 2000);
      expect(afterPayment.unpaidCreditAmount, 0);
      expect(afterPayment.outstandingCreditAmount, 0);
      expect(afterPayment.outstandingCreditCount, 0);
    });
  });
}
