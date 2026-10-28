import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wanma/core/constants/app_constants.dart';
import 'package:wanma/services/analytics_service.dart';
import 'package:wanma/services/export_service.dart';

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

  group('Persistance locale', () {
    test(
      'les produits, clients et mouvements survivent à la fermeture',
      () async {
        final product = await harness.createProduct(
          name: 'Savon',
          unitPrice: 800,
          initialQuantity: 30,
        );
        final client = await harness.createClient(
          firstName: 'Aliou',
          lastName: 'Touré',
          phone: '70 555 66 77',
        );
        await harness.inventoryService.recordStockOut(
          productId: product.id!,
          clientId: client.id,
          quantity: 5,
        );

        await harness.database.close();
        await harness.database.reopen();

        final products = await harness.productRepository.getAll();
        final clients = await harness.clientRepository.getAll();
        final movements = await harness.movementRepository.getAll();
        expect(products.single.quantity, 25);
        expect(clients.single.fullName, 'Aliou Touré');
        expect(movements, hasLength(2));
        expect(
          movements.where((movement) => movement.isExit).single.clientFullName,
          'Aliou Touré',
        );
      },
    );
  });

  group('Sécurité locale', () {
    test('le PIN est salé, vérifié et désactivable', () async {
      final security = harness.securityService;
      await security.initialize();
      expect(security.pinEnabled, isFalse);
      expect(await security.verifyPin('1234'), isFalse);

      await security.setPin('1234');
      expect(security.pinEnabled, isTrue);
      expect(await security.verifyPin('1234'), isTrue);
      expect(await security.verifyPin('0000'), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wanma.pin.hash'), isNot('1234'));
      expect(prefs.getString('wanma.pin.salt'), isNotNull);
      expect(prefs.getBool('wanma.pin.enabled'), isTrue);

      await security.disablePin();
      expect(security.pinEnabled, isFalse);
      expect(await security.verifyPin('1234'), isFalse);
    });

    test('l’application se verrouille et se déverrouille', () async {
      await harness.securityService.initialize();
      await harness.securityService.setPin('4321');
      final appState = await harness.createAppState();
      addTearDown(appState.dispose);

      expect(appState.pinEnabled, isTrue);
      expect(appState.isLocked, isTrue);
      expect(await appState.unlock('0000'), isFalse);
      expect(appState.isLocked, isTrue);
      expect(await appState.unlock('4321'), isTrue);
      expect(appState.isLocked, isFalse);

      appState.lock();
      expect(appState.isLocked, isTrue);
      expect(await appState.disablePin('0000'), isFalse);
      expect(await appState.disablePin('4321'), isTrue);
      expect(appState.pinEnabled, isFalse);
      expect(appState.isLocked, isFalse);
    });
  });

  group('Exports locaux', () {
    test('génère les CSV, Excel et PDF sans réseau', () async {
      final product = await harness.createProduct(
        name: 'Ciment',
        reference: 'CIM-01',
        unitPrice: 5000,
        initialQuantity: 100,
      );
      final client = await harness.createClient(
        firstName: 'Mamadou',
        lastName: 'Fall',
        phone: '78 111 22 33',
      );
      await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 30,
        isCredit: true,
      );

      final products = await harness.productRepository.getAll();
      final clients = await harness.clientRepository.getAll();
      final movements = await harness.movementRepository.getAll();
      const exportService = ExportService();

      final productsCsv = exportService.productsCsv(products);
      expect(productsCsv.take(3), <int>[0xEF, 0xBB, 0xBF]);
      final productsText = utf8.decode(productsCsv);
      expect(productsText, contains('Ciment'));
      expect(productsText, contains('CIM-01'));
      expect(productsText, contains(';'));

      final clientsText = utf8.decode(exportService.clientsCsv(clients));
      expect(clientsText, contains('Mamadou'));
      expect(clientsText, contains('78 111 22 33'));

      final movementsText = utf8.decode(exportService.movementsCsv(movements));
      expect(movementsText, contains('Sortie'));
      expect(movementsText, contains('Ciment'));
      expect(movementsText, contains('À crédit'));

      final productsExcel = exportService.productsExcel(products);
      final clientsExcel = exportService.clientsExcel(clients);
      final movementsExcel = exportService.movementsExcel(movements);
      for (final bytes in <List<int>>[
        productsExcel,
        clientsExcel,
        movementsExcel,
      ]) {
        expect(bytes.length, greaterThan(500));
        expect(String.fromCharCodes(bytes.take(2)), 'PK');
      }

      final report = AnalyticsService.buildReport(
        period: AnalyticsService.periodForToday(),
        products: products,
        movements: movements,
      );
      expect(report.creditAmount, 150000);
      expect(report.unpaidCreditAmount, 150000);
      expect(exportService.reportCsv(report), isNotEmpty);
      expect(
        exportService.reportExcel(report, products).length,
        greaterThan(500),
      );
      final pdf = await exportService.reportPdf(report, products: products);
      expect(pdf.length, greaterThan(1000));
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    });
  });

  group('Fonctionnement hors ligne', () {
    test('le manifeste Android ne demande pas l’accès Internet', () async {
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      expect(await manifest.exists(), isTrue);
      final content = await manifest.readAsString();
      expect(content, isNot(contains('android.permission.INTERNET')));
      expect(content, contains('android:label="Wanma"'));
    });

    test('les dépendances ne contiennent ni Firebase ni client HTTP', () async {
      final pubspec = await File('pubspec.yaml').readAsString();
      expect(pubspec, isNot(contains('firebase')));
      expect(pubspec, isNot(contains('cloud_firestore')));
      expect(pubspec, isNot(contains('http:')));
      expect(pubspec, contains('sqflite'));
      expect(pubspec, contains('flutter_localizations'));
      expect(AppConstants.databaseName, 'wanma.db');
    });
  });
}
