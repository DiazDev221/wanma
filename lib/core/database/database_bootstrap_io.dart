import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../constants/app_constants.dart';

/// Sur ordinateur, sqflite n'embarque pas de moteur SQLite : il faut activer
/// le backend FFI et choisir un dossier persistant indépendant du répertoire
/// courant.
Future<String?> initializeDatabaseStorage() async {
  if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
    return null;
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final supportDirectory = await getApplicationSupportDirectory();
  return p.join(supportDirectory.path, AppConstants.databaseName);
}
