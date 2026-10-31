import 'package:flutter_test/flutter_test.dart';

import 'package:wanma/services/phone_service.dart';

void main() {
  group('PhoneService', () {
    test('prépare un appel avec le numéro normalisé', () {
      final uri = PhoneService.telephoneUri('+221 77 123 45 67');

      expect(uri, isNotNull);
      expect(uri!.scheme, 'tel');
      expect(uri.path, '+221771234567');
      expect(uri.toString(), 'tel:+221771234567');
    });

    test('refuse un numéro sans chiffre', () {
      expect(PhoneService.telephoneUri(''), isNull);
      expect(PhoneService.telephoneUri(' + ()- '), isNull);
    });
  });
}
