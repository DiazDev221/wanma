import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:wanma/app.dart';
import 'package:wanma/core/theme/app_theme.dart';
import 'package:wanma/state/app_state.dart';
import 'package:wanma/ui/screens/clients/client_detail_screen.dart';
import 'package:wanma/ui/screens/clients/client_form_screen.dart';
import 'package:wanma/ui/screens/help_screen.dart';
import 'package:wanma/ui/screens/movements/movement_detail_screen.dart';
import 'package:wanma/ui/screens/products/low_stock_screen.dart';
import 'package:wanma/ui/screens/products/product_detail_screen.dart';
import 'package:wanma/ui/screens/products/product_form_screen.dart';
import 'package:wanma/ui/screens/reports/reports_screen.dart';
import 'package:wanma/ui/screens/settings/backup_restore_screen.dart';
import 'package:wanma/ui/screens/settings/settings_screen.dart';
import 'package:wanma/ui/screens/stock/stock_entry_screen.dart';
import 'package:wanma/ui/screens/stock/stock_exit_screen.dart';

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

  testWidgets('les cinq onglets se rendent sur un petit écran', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late AppState appState;
    await tester.runAsync(() async {
      final product = await harness.createProduct(
        name: 'Riz parfumé',
        reference: 'RIZ-01',
        unitPrice: 12500,
        initialQuantity: 8,
        lowStockThreshold: 10,
      );
      final client = await harness.createClient(
        firstName: 'Aïssatou',
        lastName: 'Diallo',
        phone: '77 000 11 22',
      );
      await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
      );
      appState = await harness.createAppState();
    });
    addTearDown(appState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const WanmaApp(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Accueil'), findsWidgets);
    expect(tester.takeException(), isNull);

    Future<void> openTab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull);
    }

    await openTab('Produits');
    expect(find.text('Riz parfumé'), findsWidgets);

    await openTab('Clients');
    expect(find.text('Aïssatou Diallo'), findsWidgets);

    await openTab('Activité');
    expect(find.text('Historique'), findsWidgets);

    await openTab('Outils');
    expect(find.text('Outils du magasin'), findsWidgets);

    await openTab('Accueil');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('les écrans restent lisibles avec un texte agrandi', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    late AppState appState;
    await tester.runAsync(() async {
      final product = await harness.createProduct(
        name: 'Huile de palme raffinée 5 litres',
        reference: 'HUILE-2026-001',
        unitPrice: 12500,
        initialQuantity: 8,
        lowStockThreshold: 10,
      );
      final client = await harness.createClient(
        firstName: 'Aïssatou',
        lastName: 'Diallo',
        phone: '77 000 11 22',
      );
      await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
      );
      appState = await harness.createAppState();
    });
    addTearDown(appState.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const WanmaApp(),
      ),
    );
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);

    Future<void> openTabLarge(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull);
    }

    await openTabLarge('Produits');
    await openTabLarge('Clients');
    await openTabLarge('Activité');
    await openTabLarge('Outils');
    await openTabLarge('Accueil');
    expect(tester.takeException(), isNull);
  });

  testWidgets('les écrans principaux se rendent avec un texte agrandi', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    late AppState appState;
    late int productId;
    late int clientId;
    late int movementId;
    await tester.runAsync(() async {
      final product = await harness.createProduct(
        name: 'Huile de palme raffinée 5 litres',
        reference: 'HUILE-2026-001',
        unitPrice: 12500,
        initialQuantity: 8,
        lowStockThreshold: 10,
      );
      final client = await harness.createClient(
        firstName: 'Aïssatou',
        lastName: 'Diallo',
        phone: '77 000 11 22',
      );
      final movement = await harness.inventoryService.recordStockOut(
        productId: product.id!,
        clientId: client.id,
        quantity: 2,
      );
      productId = product.id!;
      clientId = client.id!;
      movementId = movement.id!;
      appState = await harness.createAppState();
    });
    addTearDown(appState.dispose);

    final screens = <String, Widget>{
      'Nouveau produit': const ProductFormScreen(),
      'Fiche produit': ProductDetailScreen(productId: productId),
      'Stock faible': const LowStockScreen(),
      'Nouveau client': const ClientFormScreen(),
      'Fiche client': ClientDetailScreen(clientId: clientId),
      'Entrée de stock': const StockEntryScreen(),
      'Sortie de stock': const StockExitScreen(),
      'Détail du mouvement': MovementDetailScreen(movementId: movementId),
      'Rapports': const ReportsScreen(),
      'Paramètres': const SettingsScreen(),
      'Sauvegarde': const BackupRestoreScreen(),
      'Guide': const HelpScreen(),
    };

    for (final entry in screens.entries) {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('fr', 'FR'),
            supportedLocales: const <Locale>[Locale('fr', 'FR')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: entry.value,
          ),
        ),
      );
      await _pumpFrames(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Débordement détecté sur l’écran « ${entry.key} ».',
      );
    }
  });
}

/// Avance de quelques images sans attendre la fin des animations, afin de
/// détecter les animations continues ou les erreurs de rendu.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}
