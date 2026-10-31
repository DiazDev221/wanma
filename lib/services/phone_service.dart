import 'package:url_launcher/url_launcher.dart';

import '../core/utils/formatters.dart';

/// Prépare un appel dans l'application Téléphone du téléphone.
///
/// Wanma n'émet pas l'appel lui-même : le composeur s'ouvre avec le numéro
/// prérempli, puis l'utilisateur confirme. Aucune permission d'appel
/// (`CALL_PHONE`) n'est donc nécessaire.
abstract final class PhoneService {
  /// Construit l'URI `tel:` correspondant au numéro affiché.
  static Uri? telephoneUri(String phone) {
    final number = AppFormatters.normalizePhone(phone);
    if (!RegExp(r'\d').hasMatch(number)) return null;
    return Uri(scheme: 'tel', path: number);
  }

  /// Ouvre le composeur avec [phone]. Retourne `false` si l'appareil ne peut
  /// pas traiter l'appel.
  static Future<bool> call(String phone) async {
    final uri = telephoneUri(phone);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
