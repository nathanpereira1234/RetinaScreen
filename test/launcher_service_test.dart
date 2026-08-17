import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/services/launcher_service.dart';

void main() {
  group('LauncherService URIs (A18)', () {
    test('mapsUri builds an https maps search with the site as query', () {
      final uri = LauncherService.mapsUri('Aravind Eye Hospital, Madurai');
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['query'], 'Aravind Eye Hospital, Madurai');
    });

    test('telUri strips formatting to digits and a leading +', () {
      final uri = LauncherService.telUri('+91 98765-43210');
      expect(uri.scheme, 'tel');
      expect(uri.path, '+919876543210');
    });

    test('telUri keeps a plain local number intact', () {
      final uri = LauncherService.telUri('9876543210');
      expect(uri.path, '9876543210');
    });

    test('whatsAppUri targets wa.me with digits-only phone and encoded text',
        () {
      final uri =
          LauncherService.whatsAppUri('+91 98765-43210', 'Hello Asha & family');
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210'); // + and separators stripped
      expect(uri.queryParameters['text'], 'Hello Asha & family');
    });

    test('smsUri uses the sms scheme with a body query', () {
      final uri = LauncherService.smsUri('+91 98765-43210', 'Please attend');
      expect(uri.scheme, 'sms');
      expect(uri.path, '+919876543210');
      expect(uri.queryParameters['body'], 'Please attend');
    });
  });
}
