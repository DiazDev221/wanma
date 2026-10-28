import 'package:flutter_test/flutter_test.dart';

import 'package:wanma/core/errors/app_exception.dart';
import 'package:wanma/data/models/client.dart';
import 'package:wanma/data/models/stock_movement.dart';

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

  group('Scénario 1 - Création d’un produit et stock initial', () {
    test('crée le produit, le stock et une entrée justificative', () async {
      final product = await harness.createProduct(
        name: 'Riz parfumé',
        reference: 'RIZ-001',
        unitPrice: 1500,
        initialQuantity: 12.5,
        unit: 'Sac',
        lowStockThreshold: 4,
      );

      expect(product.id, isNotNull);
      final stored = await harness.currentProduct(product.id!);
      expect(stored.name, 'Riz parfumé');
      expect(stored.reference, 'RIZ-001');
      expect(stored.quantity, 12.5);
      expect(stored.unitPrice, 1500);

      final movements = await harness.movementsForProduct(product.id!);
      expect(movements, hasLength(1));
      expect(movements.single.movementType, MovementType.inbound);
      expect(movements.single.quantity, 12.5);
      expect(movements.single.unitPrice, 1500);
      expect(movements.single.totalAmount, 18750);
      expect(movements.single.notes, 'Stock initial');
      expect(movements.single.isActive, isTrue);
    });

    test('un stock initial nul ne crée aucun mouvement', () async {
      final product = await harness.createProduct(initialQuantity: 0);
      expect((await harness.movementsForProduct(product.id!)).isEmpty, isTrue);
      expect((await harness.currentProduct(product.id!)).quantity, 0);
    });

    test('refuse une quantité initiale négative sans rien écrire', () async {
      await expectLater(
        harness.createProduct(initialQuantity: -1),
        throwsA(isA<ValidationException>()),
      );
      expect(await harness.productRepository.getAll(), isEmpty);
      expect(await harness.movementRepository.getAll(), isEmpty);
    });
  });

  group('Scénario 2 - Enregistrement d’une entrée de stock', () {
    test('augmente le stock et conserve les prix de l’opération', () async {
      final product = await harness.createProduct(initialQuantity: 0);
      final movement = await harness.inventoryService.recordStockIn(
        productId: product.id!,
        quantity: 4,
        unitPrice: 1200,
        notes: 'Livraison fournisseur',
      );

      expect(movement.isEntry, isTrue);
      expect(movement.totalAmount, 4800);
      expect((await harness.currentProduct(product.id!)).quantity, 4);
      final stored = await harness.movementsForProduct(product.id!);
      expect(stored, hasLength(1));
      expect(stored.single.notes, 'Livraison fournisseur');
    });

    test('refuse une quantité nulle ou négative', () async {
      final product = await harness.createProduct(initialQuantity: 0);
      await expectLater(
        harness.inventoryService.recordStockIn(
          productId: product.id!,
          quantity: 0,
        ),
        throwsA(isA<StockException>()),
      );
      await expectLater(
        harness.inventoryService.recordStockIn(
          productId: product.id!,
          quantity: -2,
        ),
        throwsA(isA<StockException>()),
      );
      expect((await harness.currentProduct(product.id!)).quantity, 0);
    });
  });

  group('Scénario 3 - Enregistrement d’une sortie de stock', () {
    test('diminue le stock et lie le client au mouvement', () async {
      final product = await harness.createProduct(initialQuantity: 10);
      final client = await harness.createClient();
      final movement = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 3,
        unitPrice: 1800,
        notes: 'Vente comptoir',
      );

      expect(movement.isExit, isTrue);
      expect(movement.totalAmount, 5400);
      expect(movement.clientFullName, 'Amadou Ndiaye');
      expect(movement.clientPhone, '77 123 45 67');
      expect((await harness.currentProduct(product.id!)).quantity, 7);

      final clientMovements = await harness.movementRepository.getForClient(
        client.id!,
      );
      expect(clientMovements, hasLength(1));
      expect(clientMovements.single.id, movement.id);
    });

    test('utilise le prix courant du produit par défaut', () async {
      final product = await harness.createProduct(
        initialQuantity: 10,
        unitPrice: 2500,
      );
      final client = await harness.createClient();
      final movement = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
      );
      expect(movement.unitPrice, 2500);
      expect(movement.totalAmount, 5000);
    });
  });

  group('Scénario 4 - Refus d’une sortie supérieure au stock', () {
    test('refuse la survente et ne modifie ni stock ni historique', () async {
      final product = await harness.createProduct(initialQuantity: 2);
      final client = await harness.createClient();

      await expectLater(
        harness.inventoryService.recordStockOut(
          productId: product.id!,
          clientId: client.id,
          quantity: 3,
        ),
        throwsA(isA<StockException>()),
      );

      expect((await harness.currentProduct(product.id!)).quantity, 2);
      final movements = await harness.movementsForProduct(product.id!);
      expect(movements, hasLength(1));
      expect(movements.single.quantity, 2);
    });

    test('refuse le stock épuisé sans créer de mouvement', () async {
      final product = await harness.createProduct(initialQuantity: 0);
      final client = await harness.createClient();
      await expectLater(
        harness.inventoryService.recordStockOut(
          productId: product.id!,
          clientId: client.id,
          quantity: 1,
        ),
        throwsA(isA<StockException>()),
      );
      expect(await harness.movementRepository.getAll(), isEmpty);
    });
  });

  group('Scénario 5 - Atomicité client et sortie', () {
    test('crée le client et la sortie dans la même transaction', () async {
      final product = await harness.createProduct(initialQuantity: 5);
      final movement = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        quantity: 2,
        newClient: Client(
          firstName: 'Fatou',
          lastName: 'Diop',
          phone: '76 987 65 43',
          createdAt: DateTime(2026, 2, 1),
        ),
      );

      expect(movement.clientFullName, 'Fatou Diop');
      expect(await harness.clientRepository.getAll(), hasLength(1));
      expect((await harness.currentProduct(product.id!)).quantity, 3);
    });

    test('annule le client créé si le numéro est en doublon', () async {
      final product = await harness.createProduct(initialQuantity: 5);
      await harness.createClient();

      await expectLater(
        harness.inventoryService.recordStockOut(
          productId: product.id!,
          quantity: 1,
          newClient: Client(
            firstName: 'Autre',
            lastName: 'Client',
            phone: '771234567',
            createdAt: DateTime(2026, 2, 1),
          ),
        ),
        throwsA(isA<DuplicatePhoneException>()),
      );

      expect(await harness.clientRepository.getAll(), hasLength(1));
      expect((await harness.currentProduct(product.id!)).quantity, 5);
      final movements = await harness.movementsForProduct(product.id!);
      expect(movements, hasLength(1));
    });
  });

  group('Scénario 6 - Conservation des prix historiques', () {
    test('modifier le produit ne change pas les anciens mouvements', () async {
      final product = await harness.createProduct(
        initialQuantity: 10,
        unitPrice: 1000,
      );
      final client = await harness.createClient();
      final exit = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
      );
      expect(exit.totalAmount, 2000);

      final refreshed = await harness.currentProduct(product.id!);
      await harness.productRepository.update(
        refreshed.copyWith(
          unitPrice: 1500,
          name: 'Riz premium',
          updatedAt: DateTime.now(),
        ),
      );

      final updatedProduct = await harness.currentProduct(product.id!);
      expect(updatedProduct.unitPrice, 1500);
      expect(updatedProduct.name, 'Riz premium');
      expect(updatedProduct.quantity, 8);

      final movements = await harness.movementsForProduct(product.id!);
      final oldExit = movements.firstWhere((m) => m.id == exit.id);
      expect(oldExit.unitPrice, 1000);
      expect(oldExit.totalAmount, 2000);
      expect(oldExit.productName, 'Riz premium');

      final newExit = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 1,
      );
      expect(newExit.unitPrice, 1500);
      expect(newExit.totalAmount, 1500);
    });
  });

  group('Scénario 7 - Annulation d’une sortie', () {
    test('réintègre le stock et conserve une trace annulée', () async {
      final product = await harness.createProduct(initialQuantity: 10);
      final client = await harness.createClient();
      final exit = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 4,
      );
      expect((await harness.currentProduct(product.id!)).quantity, 6);

      await harness.inventoryService.cancelMovement(
        movementId: exit.id!,
        reason: 'Retour du client',
      );

      expect((await harness.currentProduct(product.id!)).quantity, 10);
      final movements = await harness.movementsForProduct(product.id!);
      final cancelled = movements.firstWhere((m) => m.id == exit.id);
      expect(cancelled.status, MovementStatus.cancelled);
      expect(cancelled.cancellationReason, 'Retour du client');
      expect(cancelled.cancelledAt, isNotNull);
      expect(movements, hasLength(2));

      await expectLater(
        harness.inventoryService.cancelMovement(movementId: exit.id!),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Scénario 8 - Annulation d’une entrée contrôlée', () {
    test('retire du stock une entrée annulée', () async {
      final product = await harness.createProduct(initialQuantity: 10);
      final initialMovement = (await harness.movementsForProduct(product.id!))
          .single;

      await harness.inventoryService.cancelMovement(
        movementId: initialMovement.id!,
        reason: 'Inventaire erroné',
      );

      expect((await harness.currentProduct(product.id!)).quantity, 0);
      final movement = (await harness.movementsForProduct(product.id!)).single;
      expect(movement.status, MovementStatus.cancelled);
    });

    test('refuse l’annulation si le stock actuel est insuffisant', () async {
      final product = await harness.createProduct(initialQuantity: 10);
      final firstEntry = (await harness.movementsForProduct(product.id!))
          .single;
      final secondEntry = await harness.inventoryService.recordStockIn(
        productId: product.id!,
        quantity: 10,
      );
      final client = await harness.createClient();
      await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 18,
      );
      expect((await harness.currentProduct(product.id!)).quantity, 2);

      await expectLater(
        harness.inventoryService.cancelMovement(
          movementId: secondEntry.id!,
          reason: 'Retour fournisseur',
        ),
        throwsA(isA<StockException>()),
      );

      expect((await harness.currentProduct(product.id!)).quantity, 2);
      final movements = await harness.movementsForProduct(product.id!);
      expect(
        movements.firstWhere((m) => m.id == secondEntry.id).status,
        MovementStatus.active,
      );
      expect(firstEntry.status, MovementStatus.active);
    });
  });

  group('Scénario 9 - Suppression d’un produit avec historique', () {
    test('bloque la suppression si un mouvement existe', () async {
      final product = await harness.createProduct(initialQuantity: 3);
      await expectLater(
        harness.productRepository.delete(product.id!),
        throwsA(isA<AppException>()),
      );
      expect(await harness.productRepository.findById(product.id!), isNotNull);
    });

    test('autorise la suppression sans aucun mouvement', () async {
      final product = await harness.createProduct(initialQuantity: 0);
      await harness.productRepository.delete(product.id!);
      expect(await harness.productRepository.findById(product.id!), isNull);
    });
  });

  group('Scénario 10 - Suppression d’un client avec historique', () {
    test('bloque la suppression si une sortie existe', () async {
      final product = await harness.createProduct(initialQuantity: 4);
      final client = await harness.createClient();
      await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 1,
      );
      await expectLater(
        harness.clientRepository.delete(client.id!),
        throwsA(isA<AppException>()),
      );
      expect(await harness.clientRepository.findById(client.id!), isNotNull);
    });

    test('autorise la suppression sans sortie', () async {
      final client = await harness.createClient();
      await harness.clientRepository.delete(client.id!);
      expect(await harness.clientRepository.findById(client.id!), isNull);
    });
  });

  group('Scénario 11 - Ventes à crédit', () {
    test('enregistre une sortie à crédit puis la marque payée', () async {
      final product = await harness.createProduct(
        initialQuantity: 10,
        unitPrice: 1000,
      );
      final client = await harness.createClient();
      final exit = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
        isCredit: true,
      );

      expect(exit.isCredit, isTrue);
      expect(exit.isCreditSale, isTrue);
      expect(exit.isCreditPending, isTrue);
      expect(exit.isPaid, isFalse);
      expect(exit.paidAt, isNull);
      expect((await harness.currentProduct(product.id!)).quantity, 8);

      final stored = (await harness.movementsForProduct(product.id!))
          .firstWhere((movement) => movement.id == exit.id);
      expect(stored.paymentStatus, PaymentStatus.credit);

      await harness.inventoryService.markMovementPaid(movementId: exit.id!);

      final paid = (await harness.movementsForProduct(product.id!))
          .firstWhere((movement) => movement.id == exit.id);
      expect(paid.paymentStatus, PaymentStatus.paid);
      expect(paid.isCreditSale, isTrue);
      expect(paid.isCreditPending, isFalse);
      expect(paid.paidAt, isNotNull);
      expect(paid.quantity, 2);
      expect((await harness.currentProduct(product.id!)).quantity, 8);
    });

    test('une sortie comptant est payée par défaut', () async {
      final product = await harness.createProduct(initialQuantity: 5);
      final client = await harness.createClient();
      final exit = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 1,
      );

      expect(exit.isPaid, isTrue);
      expect(exit.isCreditSale, isFalse);
      expect(exit.isCreditPending, isFalse);
      expect(exit.paidAt, isNotNull);
    });

    test('refuse un paiement en double ou sur une entrée', () async {
      final product = await harness.createProduct(initialQuantity: 5);
      final client = await harness.createClient();
      final exit = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 1,
        isCredit: true,
      );

      await harness.inventoryService.markMovementPaid(movementId: exit.id!);
      await expectLater(
        harness.inventoryService.markMovementPaid(movementId: exit.id!),
        throwsA(isA<AppException>()),
      );

      final entry = await harness.inventoryService.recordStockIn(
        productId: product.id!,
        quantity: 2,
      );
      await expectLater(
        harness.inventoryService.markMovementPaid(movementId: entry.id!),
        throwsA(isA<ValidationException>()),
      );
    });

    test('une sortie à crédit annulée n’est plus à recouvrer', () async {
      final product = await harness.createProduct(initialQuantity: 5);
      final client = await harness.createClient();
      final exit = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
        isCredit: true,
      );

      await harness.inventoryService.cancelMovement(movementId: exit.id!);
      final cancelled = (await harness.movementsForProduct(product.id!))
          .firstWhere((movement) => movement.id == exit.id);
      expect(cancelled.isCreditPending, isFalse);
      expect(cancelled.paymentStatus, PaymentStatus.credit);

      await expectLater(
        harness.inventoryService.markMovementPaid(movementId: exit.id!),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Scénario 12 - Doublons de téléphone', () {
    test('refuse un doublon puis l’accepte après confirmation', () async {
      final first = await harness.createClient(phone: '77 123 45 67');
      await expectLater(
        harness.createClient(
          firstName: 'Autre',
          lastName: 'Personne',
          phone: '771234567',
        ),
        throwsA(
          isA<DuplicatePhoneException>().having(
            (e) => e.existingClient.id,
            'client existant',
            first.id,
          ),
        ),
      );

      final duplicate = await harness.createClient(
        firstName: 'Autre',
        lastName: 'Personne',
        phone: '771234567',
        allowDuplicatePhone: true,
      );
      expect(duplicate.id, isNotNull);
      expect(await harness.clientRepository.getAll(), hasLength(2));
    });

    test('contrôle aussi les doublons lors d’une modification', () async {
      await harness.createClient(
        firstName: 'Amadou',
        lastName: 'Ndiaye',
        phone: '77 123 45 67',
      );
      final second = await harness.createClient(
        firstName: 'Fatou',
        lastName: 'Diop',
        phone: '76 987 65 43',
      );

      await expectLater(
        harness.clientRepository.update(second.copyWith(phone: '77 123 45 67')),
        throwsA(isA<DuplicatePhoneException>()),
      );

      await harness.clientRepository.update(
        second.copyWith(phone: '77 123 45 67'),
        allowDuplicatePhone: true,
      );
      final stored = await harness.clientRepository.findById(second.id!);
      expect(stored!.phone, '77 123 45 67');
      expect(stored.normalizedPhone, '771234567');
    });
  });
}
