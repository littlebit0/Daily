import 'package:url_launcher/url_launcher.dart';

abstract final class SiriShortcutInstaller {
  static final Uri signalShortcutUri = Uri.parse(
    'https://www.icloud.com/shortcuts/d38300f25eca434db08375c9924b4e18',
  );

  static Future<bool> openSignalInstaller() async {
    try {
      return await launchUrl(
        signalShortcutUri,
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      return false;
    }
  }
}
