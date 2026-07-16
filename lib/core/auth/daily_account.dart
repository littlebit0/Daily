import 'apple_account.dart';
import 'google_account.dart';

/// A local Daily account can have more than one verified sign-in provider.
/// Provider identities are only attached after that provider's own sign-in
/// succeeds; email addresses are never used to merge separate accounts.
class DailyAccount {
  const DailyAccount({required this.id, this.appleAccount, this.googleAccount});

  final String id;
  final AppleAccount? appleAccount;
  final GoogleAccount? googleAccount;

  bool get hasProviders => appleAccount != null || googleAccount != null;

  DailyAccount copyWith({
    AppleAccount? appleAccount,
    GoogleAccount? googleAccount,
    bool clearAppleAccount = false,
    bool clearGoogleAccount = false,
  }) {
    return DailyAccount(
      id: id,
      appleAccount: clearAppleAccount
          ? null
          : appleAccount ?? this.appleAccount,
      googleAccount: clearGoogleAccount
          ? null
          : googleAccount ?? this.googleAccount,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    if (appleAccount != null)
      'appleAccount': {
        'userIdentifier': appleAccount!.userIdentifier,
        if (appleAccount!.email != null) 'email': appleAccount!.email,
        if (appleAccount!.givenName != null)
          'givenName': appleAccount!.givenName,
        if (appleAccount!.familyName != null)
          'familyName': appleAccount!.familyName,
      },
    if (googleAccount != null) 'googleAccount': googleAccount!.toJson(),
  };

  static DailyAccount? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final id = value['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    final apple = _appleAccountFromJson(value['appleAccount']);
    final google = GoogleAccount.fromJson(value['googleAccount']);
    final account = DailyAccount(
      id: id,
      appleAccount: apple,
      googleAccount: google,
    );
    return account.hasProviders ? account : null;
  }

  static AppleAccount? _appleAccountFromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final userIdentifier = value['userIdentifier']?.toString().trim() ?? '';
    if (userIdentifier.isEmpty) {
      return null;
    }
    String? optionalValue(String key) {
      final result = value[key]?.toString().trim();
      return result == null || result.isEmpty ? null : result;
    }

    return AppleAccount(
      userIdentifier: userIdentifier,
      email: optionalValue('email'),
      givenName: optionalValue('givenName'),
      familyName: optionalValue('familyName'),
    );
  }
}
