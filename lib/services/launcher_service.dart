import 'package:url_launcher/url_launcher.dart';

/// Launches external apps for the last-mile flow (A18): maps navigation to a
/// referral site, and the dialer for a patient's phone.
///
/// The URI builders are pure and static so they can be unit-tested without a
/// platform channel (see test/launcher_service_test.dart).
class LauncherService {
  const LauncherService();

  /// A Google Maps search URL for a free-text site name or address.
  static Uri mapsUri(String query) => Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=${Uri.encodeComponent(query)}',
      );

  /// A `tel:` URI, stripped to digits and a leading `+`.
  static Uri telUri(String phone) =>
      Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));

  /// A `wa.me` URL that opens WhatsApp with [message] pre-filled to [phone].
  /// The number is reduced to digits (wa.me rejects `+`, spaces, dashes); the
  /// health worker still taps send, so no message is sent automatically.
  static Uri whatsAppUri(String phone, String message) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
  }

  /// An `sms:` URI with a pre-filled body. `?body=` is honoured by Android and
  /// iOS; the user reviews and sends it themselves.
  static Uri smsUri(String phone, String message) => Uri(
        scheme: 'sms',
        path: phone.replaceAll(RegExp(r'[^0-9+]'), ''),
        queryParameters: {'body': message},
      );

  Future<bool> openMaps(String site) =>
      launchUrl(mapsUri(site), mode: LaunchMode.externalApplication);

  Future<bool> dial(String phone) => launchUrl(telUri(phone));

  /// Open WhatsApp with a pre-filled patient reminder.
  Future<bool> whatsApp(String phone, String message) => launchUrl(
        whatsAppUri(phone, message),
        mode: LaunchMode.externalApplication,
      );

  /// Open the SMS composer with a pre-filled patient reminder.
  Future<bool> sms(String phone, String message) =>
      launchUrl(smsUri(phone, message));
}
