import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/core/security/vault_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultBackupService Unit Tests', () {
    test('Armored string formatting has proper header and footer', () {
      expect(VaultBackupService.backupHeader, 'FEESVAULT-BACKUP-V1::');
      expect(VaultBackupService.backupFooter, '::END');
    });

    test('Passphrase validation requires at least 4 characters', () {
      expect(
        () => VaultBackupService.verifyAndDecryptBackup(
          armoredBackup: 'invalid',
          passphrase: '123',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('Malformed backup string throws FormatException', () {
      expect(
        () => VaultBackupService.verifyAndDecryptBackup(
          armoredBackup: '${VaultBackupService.backupHeader}NotValidBase64JSON${VaultBackupService.backupFooter}',
          passphrase: 'correct_passphrase_123',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
