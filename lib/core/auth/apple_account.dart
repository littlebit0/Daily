class AppleAccount {
  const AppleAccount({
    required this.userIdentifier,
    this.email,
    this.givenName,
    this.familyName,
  });

  final String userIdentifier;
  final String? email;
  final String? givenName;
  final String? familyName;

  String? get displayName {
    final parts = [
      if (familyName != null && familyName!.trim().isNotEmpty)
        familyName!.trim(),
      if (givenName != null && givenName!.trim().isNotEmpty) givenName!.trim(),
    ];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('');
  }
}
