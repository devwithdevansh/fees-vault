/// Application wide constants for FeesVault.
class AppConstants {
  static const String appDisplayName = 'FeesVault';
  static const String bundleIdentifier = 'com.feesvault.fees_vault';
  static const String appVersion = '1.0.0';

  // Security channel name matching iOS Swift AppDelegate
  static const String securityChannelName = 'com.feesvault.security';

  // Secure storage keys
  static const String dbPassphraseKey = 'fees_vault_db_key_v1';
  static const String keyInitializationStatusKey = 'fees_vault_key_status';

  // Settings keys
  static const String settingBusinessName = 'business_name';
  static const String settingCurrency = 'currency';
  static const String settingOnboardingDone = 'onboarding_acknowledged';
  static const String settingDeveloperActivated = 'developer_license_activated';
  static const String settingReceiptCounter = 'receipt_counter';

  // Developer License Key (one-time activation)
  static const String masterDeveloperKey = 'FEES-VAULT-DEV-KEY';

  // Payment Methods (fixed labels per MVP specs)
  static const List<String> paymentMethods = [
    'Cash',
    'UPI',
    'Bank transfer',
    'Other',
  ];

  // Database filename & folder
  static const String vaultDirectoryName = 'vault';
  static const String databaseFileName = 'fees_vault.db';
}
