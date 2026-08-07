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

  Future<bool> openMaps(String site) =>
      launchUrl(mapsUri(site), mode: LaunchMode.externalApplication);

  Future<bool> dial(String phone) => launchUrl(telUri(phone));
}
