import 'package:intl/intl.dart';

/// Formatage des montants, quantités, dates et numéros de téléphone.
abstract final class AppFormatters {
  static const String _locale = 'fr_FR';

  static final NumberFormat _integerNumber = NumberFormat.decimalPattern(
    _locale,
  );
  static final NumberFormat _quantityNumber = NumberFormat(
    '#,##0.###',
    _locale,
  );

  static String _cleanSpaces(String value) =>
      value.replaceAll('\u202f', ' ').replaceAll('\u00a0', ' ');

  static String money(num amount) {
    final rounded = amount.round();
    return '${_cleanSpaces(_integerNumber.format(rounded))} FCFA';
  }

  static String number(num value) => _cleanSpaces(_integerNumber.format(value));

  static String quantity(double value) {
    final formatted = value == value.roundToDouble()
        ? _integerNumber.format(value)
        : _quantityNumber.format(value);
    return _cleanSpaces(formatted);
  }

  static String quantityWithUnit(double value, String unit) =>
      '${quantity(value)} ${unit.toLowerCase()}';

  static String date(DateTime value) =>
      DateFormat('dd/MM/yyyy', _locale).format(value);

  static String dateTime(DateTime value) =>
      DateFormat('dd/MM/yyyy HH:mm', _locale).format(value);

  static String time(DateTime value) =>
      DateFormat('HH:mm', _locale).format(value);

  static String longDate(DateTime value) =>
      DateFormat('EEEE d MMMM yyyy', _locale).format(value);

  /// Libellé de regroupement d'une journée : aujourd'hui, hier ou date longue.
  static String dayLabel(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final target = DateTime(value.year, value.month, value.day);
    final difference = today.difference(target).inDays;
    if (difference == 0) return 'Aujourd’hui';
    if (difference == 1) return 'Hier';
    return longDate(value);
  }

  static String shortDayMonth(DateTime value) =>
      DateFormat('dd MMM', _locale).format(value);

  static String monthYear(DateTime value) =>
      DateFormat('MMMM yyyy', _locale).format(value);

  static String fileTimestamp(DateTime value) =>
      DateFormat('yyyyMMdd_HHmmss').format(value);

  /// Normalise un téléphone pour la recherche et la détection de doublons.
  static String normalizePhone(String phone) {
    final trimmed = phone.trim();
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final char = trimmed[i];
      if (char == '+' && buffer.isEmpty) {
        buffer.write(char);
      } else if (RegExp(r'\d').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static String initials(String firstName, [String? lastName]) {
    final a = firstName.trim();
    final b = lastName?.trim() ?? '';
    final first = a.isNotEmpty ? a[0] : '';
    final second = b.isNotEmpty ? b[0] : '';
    final result = '$first$second'.toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  /// Deux lettres pour l'avatar d'un produit.
  static String productInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return (word.length > 1 ? word.substring(0, 2) : word).toUpperCase();
    }
    return '${words.first[0]}${words.elementAt(1)[0]}'.toUpperCase();
  }
}
