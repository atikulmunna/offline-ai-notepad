class AppLockSettings {
  const AppLockSettings({
    required this.isEnabled,
    required this.pinHash,
    required this.saltBase64,
  });

  final bool isEnabled;
  final String? pinHash;
  final String? saltBase64;
}
