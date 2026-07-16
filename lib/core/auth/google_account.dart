class GoogleAccount {
  const GoogleAccount({required this.email, this.displayName});

  final String email;
  final String? displayName;

  Map<String, Object?> toJson() => {
    'email': email,
    if (displayName != null) 'displayName': displayName,
  };

  static GoogleAccount? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final email = value['email']?.toString().trim() ?? '';
    if (email.isEmpty) {
      return null;
    }
    final displayName = value['displayName']?.toString().trim();
    return GoogleAccount(
      email: email,
      displayName: displayName == null || displayName.isEmpty
          ? null
          : displayName,
    );
  }
}
