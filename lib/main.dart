import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/database/database_bootstrap.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initializeDateFormatting('fr_FR', null);

  final databasePath = await initializeDatabaseStorage();
  final appState = AppState.production(databasePath: databasePath);
  unawaited(appState.initialize());

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const WanmaApp(),
    ),
  );
}
