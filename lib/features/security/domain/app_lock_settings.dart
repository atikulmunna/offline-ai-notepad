class AppLockSettings {
  const AppLockSettings({
    required this.isEnabled,
    required this.pinHash,
  });

  final bool isEnabled;
  final String? pinHash;
}
