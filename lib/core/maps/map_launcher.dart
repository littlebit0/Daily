import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an event location through the platform's native map chooser.
///
/// Mobile platforms handle installed map apps themselves. Desktop platforms
/// return the map selected in their native dialog so the default browser can
/// open the matching web map.
class MapLauncher {
  MapLauncher({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'daily/map_launcher';

  final MethodChannel _channel;

  Future<void> openLocation(String location) async {
    final query = location.trim();
    if (query.isEmpty) {
      return;
    }

    try {
      final destination = await _channel.invokeMethod<String>('openLocation', {
        'location': query,
      });
      if (destination == null || destination == 'handled') {
        return;
      }
      await _openInDefaultBrowser(destination, query);
    } on MissingPluginException {
      await _openInDefaultBrowser('apple', query);
    } on PlatformException {
      await _openInDefaultBrowser('apple', query);
    }
  }

  Future<void> _openInDefaultBrowser(String destination, String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final uri = switch (destination) {
      'kakao' => Uri.parse('https://map.kakao.com/link/search/$encodedQuery'),
      'naver' => Uri.parse('https://map.naver.com/p/search/$encodedQuery'),
      _ => Uri.parse('https://maps.apple.com/?q=$encodedQuery'),
    };
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
