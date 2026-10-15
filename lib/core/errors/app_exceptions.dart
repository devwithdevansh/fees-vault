/// Custom domain exceptions for FeesVault.
class AppException implements Exception {
  final String message;
  final String? details;

  const AppException(this.message, [this.details]);

  @override
  String toString() => details != null ? '$message: $details' : message;
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.details]);
}

class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message, [super.details]);
}

class DatabaseSecurityException extends AppException {
  const DatabaseSecurityException(super.message, [super.details]);
}

class KeyMissingException extends DatabaseSecurityException {
  const KeyMissingException([
    super.message = 'Encryption key missing in secure storage',
  ]);
}

class BiometricAuthException extends AppException {
  const BiometricAuthException(super.message, [super.details]);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.details]);
}
