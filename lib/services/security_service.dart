import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exception.dart';

/// Gestion du code PIN local.
///
/// Le PIN n'est jamais enregistré en clair : seul un condensat SHA-256 salé est
/// conservé dans les préférences locales. Il s'agit d'un verrou d'accès à
/// l'application, pas d'un chiffrement de la base SQLite.
class SecurityService {
  static const String _enabledKey = 'wanma.pin.enabled';
  static const String _hashKey = 'wanma.pin.hash';
  static const String _saltKey = 'wanma.pin.salt';

  SharedPreferences? _preferences;
  bool _pinEnabled = false;

  bool get pinEnabled => _pinEnabled;

  Future<void> initialize() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_hashKey);
    final storedSalt = prefs.getString(_saltKey);
    final declaredEnabled = prefs.getBool(_enabledKey) ?? false;
    _pinEnabled =
        declaredEnabled &&
        storedHash != null &&
        storedHash.isNotEmpty &&
        storedSalt != null &&
        storedSalt.isNotEmpty;
    if (declaredEnabled && !_pinEnabled) {
      // Configuration incohérente : on désactive proprement le verrou plutôt
      // que de bloquer définitivement l'accès aux données.
      await prefs.setBool(_enabledKey, false);
    }
  }

  Future<void> setPin(String pin) async {
    _validatePinFormat(pin);
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    final hashSaved = await prefs.setString(_hashKey, hash);
    final saltSaved = await prefs.setString(_saltKey, salt);
    final enabledSaved = await prefs.setBool(_enabledKey, true);
    if (!hashSaved || !saltSaved || !enabledSaved) {
      throw const AppException(
        'Le code PIN n’a pas pu être enregistré. Réessayez.',
      );
    }
    _pinEnabled = true;
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_hashKey);
    final storedSalt = prefs.getString(_saltKey);
    if (storedHash == null || storedSalt == null) return false;
    final candidate = _hashPin(pin, storedSalt);
    return _constantTimeEquals(candidate, storedHash);
  }

  Future<void> disablePin() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.remove(_saltKey);
    await prefs.setBool(_enabledKey, false);
    _pinEnabled = false;
  }

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static void _validatePinFormat(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const ValidationException(
        'Le code PIN doit contenir exactement 4 chiffres.',
      );
    }
  }
}
