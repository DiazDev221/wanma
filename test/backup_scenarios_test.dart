import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:wanma/core/constants/app_constants.dart';
import 'package:wanma/core/errors/app_exception.dart';

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

  group('Scénario 14 - Sauvegarde et restauration locale', () {
    test(
      'crée une sauvegarde vérifiable et restaure toutes les données',
      () async {
        final product = await harness.createProduct(
          name: 'Lait',
          reference: 'LAI-01',
          unitPrice: 12000,
          initialQuantity: 8,
          lowStockThreshold: 3,
        );
        final client = await harness.createClient(
          firstName: 'Mariama',
          lastName: 'Diallo',
          phone: '76 888 44 55',
        );
        await harness.inventoryService.recordStockOut(
          productId: product.id!,
          clientId: client.id,
          quantity: 2,
          notes: 'Vente du jour',
        );

        final backup = await harness.backupService.createBackup();
        expect(backup.fileName, startsWith('wanma_sauvegarde_'));
        expect(backup.fileName, endsWith('.${AppConstants.backupExtension}'));
        expect(backup.bytes, isNotEmpty);
        expect(backup.info.productCount, 1);
        expect(backup.info.clientCount, 1);
        expect(backup.info.movementCount, 2);

        final payload =
            jsonDecode(utf8.decode(backup.bytes)) as Map<String, dynamic>;
        expect(payload['format'], AppConstants.backupFormat);
        expect(payload['formatVersion'], AppConstants.backupFormatVersion);
        expect(payload['schemaVersion'], AppConstants.databaseVersion);
        expect(payload['checksum'], isA<String>());

        final validated = await harness.backupService.validateBackup(
          backup.bytes,
        );
        expect(validated.productCount, 1);
        expect(validated.clientCount, 1);
        expect(validated.movementCount, 2);

        await harness.createProduct(
          name: 'Produit après sauvegarde',
          initialQuantity: 0,
        );
        await harness.createClient(
          firstName: 'Nouveau',
          lastName: 'Client',
          phone: '70 000 00 00',
        );
        expect(await harness.productRepository.getAll(), hasLength(2));
        expect(await harness.clientRepository.getAll(), hasLength(2));

        final restored = await harness.backupService.restoreBackup(
          backup.bytes,
        );
        expect(restored.productCount, 1);
        expect(restored.clientCount, 1);
        expect(restored.movementCount, 2);

        final products = await harness.productRepository.getAll();
        expect(products, hasLength(1));
        expect(products.single.name, 'Lait');
        expect(products.single.quantity, 6);
        final clients = await harness.clientRepository.getAll();
        expect(clients.single.fullName, 'Mariama Diallo');
        final movements = await harness.movementRepository.getAll();
        expect(movements, hasLength(2));
        expect(
          movements.where((movement) => movement.isExit).single.notes,
          'Vente du jour',
        );
      },
    );

    test(
      'refuse une sauvegarde corrompue sans modifier la base actuelle',
      () async {
        await harness.createProduct(name: 'Riz', initialQuantity: 3);
        final backup = await harness.backupService.createBackup();
        final text = utf8.decode(backup.bytes);
        final payload = jsonDecode(text) as Map<String, dynamic>;
        payload['checksum'] = 'empreinte-invalide';
        final corrupted = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

        await expectLater(
          harness.backupService.validateBackup(corrupted),
          throwsA(isA<AppException>()),
        );
        await expectLater(
          harness.backupService.restoreBackup(corrupted),
          throwsA(isA<AppException>()),
        );

        final products = await harness.productRepository.getAll();
        expect(products.single.name, 'Riz');
        expect(products.single.quantity, 3);
      },
    );

    test('refuse un fichier qui n’est pas une sauvegarde Wanma', () async {
      await expectLater(
        harness.backupService.validateBackup(
          Uint8List.fromList(utf8.encode('{"format":"autre","database":"x"}')),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        harness.backupService.validateBackup(Uint8List(0)),
        throwsA(isA<AppException>()),
      );
    });

    test('recharge les données de l’application après restauration', () async {
      final appState = await harness.createAppState();
      addTearDown(appState.dispose);
      await appState.addProduct(
        name: 'Sucre',
        unitPrice: 600,
        initialQuantity: 20,
        unit: 'Sac',
        lowStockThreshold: 5,
      );
      final backup = await appState.createBackup();
      await appState.addProduct(
        name: 'Café',
        unitPrice: 2000,
        initialQuantity: 4,
        unit: 'Kilogramme',
        lowStockThreshold: 2,
      );
      expect(appState.products, hasLength(2));

      await appState.restoreBackup(backup.bytes);
      expect(appState.products, hasLength(1));
      expect(appState.products.single.name, 'Sucre');
      expect(appState.products.single.quantity, 20);
    });
  });
}
