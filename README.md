# FeesVault

**FeesVault** is an iPhone-first, offline fee-management application built with Flutter for single-business, single-owner operations. All client records, payments, and CRUD actions stay strictly within the local encrypted device storage with zero cloud, remote servers, analytics, or external telemetry.

---

## 1. Goal and Architectural Assumptions

- **Display Name:** `FeesVault`
- **Dart Project Name:** `fees_vault`
- **Placeholder Bundle Identifier:** `com.feesvault.fees_vault`
- **Operating Model:** 1 Owner, 1 iPhone, 1 Business, INR (`₹`, paise-precise integer calculations).
- **Core Entities:** Payers (neutral labels with optional batch/class fields), Charges (fee obligations with gross and discount), Payments (partial and full payments with monotonically increasing receipt numbers), Audit Trail (encrypted local correction logs).
- **Security Boundary:** 100% Offline. Zero external backends, no Firebase, no Supabase, no sync servers, no analytics, no remote ads, no online fonts, and no network requests.

---

## 2. Technology Stack & Packages

| Component | Technology / Library | Version | Purpose |
|---|---|---|---|
| **Framework** | Flutter (Dart SDK ^3.12.2) | 3.44.3 | Cross-platform framework with iOS design system |
| **Encrypted Database** | `sqflite_sqlcipher` | ^3.4.1 | SQLCipher 256-bit AES encrypted relational SQLite |
| **Key Management** | `flutter_secure_storage` | ^11.2.0 | iOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) & Android Keystore |
| **Biometric Auth** | `local_auth` | ^3.0.2 | System Face ID / Touch ID with device passcode fallback |
| **File Paths** | `path_provider` & `path` | ^2.1.6 / ^1.9.1 | Dedicated Application Support vault directories |
| **Formatting** | `intl` | ^0.20.3 | Strict `en_IN` Indian numbering & date formatting |
| **UUIDs** | `uuid` | ^4.6.0 | Cryptographic RFC4122 v4 entity identifiers |

---

## 3. Local Storage & Security Architecture

### Storage Isolation
- The database is stored exclusively inside the private **Application Support** directory (`<ApplicationSupport>/vault/fees_vault.db`).
- It is never placed in cache, the public Documents folder, or an iCloud container (`UIFileSharingEnabled = false`, `LSSupportsOpeningDocumentsInPlace = false`).

### Cryptographic Key Management
1. **Key Generation:** On first initialization, FeesVault generates a cryptographically secure 256-bit (32-byte) random secret using `Random.secure()`.
2. **Device-Only Keychain:** The secret is persisted to the iOS Keychain with:
   - `accessibility: KeychainAccessibility.unlocked_this_device` (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
   - `synchronizable: false` (prevents cloud synchronization over iCloud Keychain)
3. **Readback Verification:** On initial generation, the key is written and immediately read back to verify hardware persistence before creating the SQLCipher database.
4. **Fail-Closed Gate:** If a database file is detected on disk but its decryption key is missing or unreadable from secure storage, the application immediately enters a **fail-closed lockout state**. It will **never** delete the existing database, replace the key, or silently generate an empty database.

### Native iOS File Protection & Sidecars
- A native Swift MethodChannel (`com.feesvault.security`) in `AppDelegate.swift` recursively enforces:
  - `FileProtectionType.complete` (`NSFileProtectionComplete`): Files are inaccessible while the iPhone is locked.
  - `isExcludedFromBackup = true`: Prevents OS iCloud backups of the database and its sidecars (`.db-wal`, `.db-shm`, `.db-journal`).
- Effective attributes are queried and returned to Dart so security status reflects actual filesystem flags.

### App Switcher Privacy Curtain & State Machine
- When the app is backgrounded or transitioned to inactive, a native visual blur overlay (`UIVisualEffectView`) covers the window to prevent sensitive balance exposures in iOS App Switcher snapshots.
- A lock/unlock state machine closes database connection handles upon backgrounding and requires successful biometrics or device passcode verification to reopen.
- Transient inactive transitions caused by the system authentication prompt are isolated to prevent authentication loops.

---

## 4. Financial Data Model & Mathematical Invariants

1. **Paise Precision:** All currency amounts are stored and computed strictly as **64-bit integer paise** (`1 INR = 100 paise`). Floating-point arithmetic is never used for financial calculations.
2. **Input Parsing:** User input is parsed against `^\d+(\.\d{1,2})?$` and formatted using `en_IN` standards (`₹10,000`, `₹1,23,456.50`).
3. **Fee Calculation:**
   $$\text{Net Charge} = \text{Gross Fee} - \text{Discount}$$
   $$\text{Outstanding} = \text{Net Charge} - \sum \text{Valid Payments}$$
4. **Settlement Rules:**
   - $\text{Gross} > 0$, $0 \le \text{Discount} \le \text{Gross}$.
   - Payments must be positive and cannot exceed the remaining outstanding balance (credit balances are strictly rejected).
   - When editing a payment, headroom is calculated excluding that payment's previous amount.
   - When editing a charge, the net charge cannot be reduced below payments already collected.
   - Payments cannot be moved across charges.
5. **Monotonic Receipt Numbers:** Generated transactionally using an atomic sequence counter (`settings.receipt_counter`). A receipt number is never reused after a payment deletion and is never derived from row counts.
6. **Audited Corrections:** Editing or deleting a payment requires a mandatory correction reason and commits an audit event inside the same transaction. Deleting a payment restores outstanding balance immediately.
7. **Payer Deletion Safeguards:** Hard deletion is allowed only if 0 charges exist. If charges exist, the app enforces an archive action which keeps outstanding dues counted in global totals.
8. **Independent Aggregations:** Total fees raised and total collections are queried independently in SQL to prevent Cartesian JOIN multiplication.

---

## 5. Screen Overview

- **Dashboard:** All-time and current-month financial totals, quick action buttons (Add Payer, Add Charge, Record Payment), overdue charges alert list, and recent payments.
- **Payers:** Real-time search by name, phone, or batch; active vs archived toggle; individual outstanding balances; detail screen with linked charges.
- **Charge Detail:** Fee breakdown (Gross, Discount, Net, Paid, Outstanding), due date status badge, payment history, and inline payment recording CTA.
- **Payments:** List with date and method filters (Cash, UPI, Bank transfer, Other), and on-screen printable receipt view with business header and remaining balance.
- **Settings & Vault Security:** Business display name editor, "Lock Vault Now" button, real-time security attribute inspector (SQLCipher cipher version, Keychain policy, file protection), and recovery limitations notice.

---

## 6. Security Boundaries & Recovery Limitations

> [!WARNING]
> **Strict Local Storage Notice:**
> 1. Because records never leave the physical device, **no automatic cloud recovery exists**.
> 2. Deleting FeesVault, wiping the device, or losing access to the device passcode/Keychain will cause **permanent, irreversible loss of all records**.
> 3. Apple's backup-exclusion flag is guidance to the operating system, not an absolute cryptographic guarantee.
> 4. Device-only Keychain keys cannot migrate to a replacement phone.
> 5. A future backup feature requires tested, independent password-based authenticated encryption to an offline user-controlled destination.

---

## 7. iOS Distribution & Installation Routes

Because building and signing iOS binaries requires macOS and Xcode, testing or deploying FeesVault to an iPhone requires one of the following routes:

1. **Free Personal Team Provisioning:**
   - Connect iPhone to a Mac via USB.
   - Run in Xcode using a free Apple ID.
   - *Limitation:* Provisioning profile expires after 7 days; requires periodic re-signing.
2. **Apple Developer Program (Ad-Hoc / Registered Devices):**
   - Requires paid Apple Developer Program membership (\$99/year).
   - Register the client iPhone UDID in the developer portal.
   - Builds remain valid for up to 1 year.
3. **Apple TestFlight:**
   - Upload signed archive via Xcode / Transporter.
   - Invite client via email or public link.
   - *Limitation:* Builds expire after 90 days.
4. **Unlisted App Distribution:**
   - Requires Apple App Store review and approval for unlisted distribution.
   - Accessible via direct link; anyone with the link can install.

---

## 8. Verification & Test Results

Run tests and analysis locally using the Flutter toolchain:

```bash
# 1. Run static analysis
flutter analyze

# 2. Run unit and widget test suite
flutter test
```

### Verified Acceptance Checks:
- [x] Strict integer paise currency parsing rejecting $>2$ decimal places and negative numbers.
- [x] Fee math: INR 10,000 charge - INR 1,000 discount + INR 4,000 payment = INR 5,000 outstanding.
- [x] Settlement: Second INR 5,000 payment settles charge; extra payments exceed headroom and are rejected.
- [x] Headroom check: Charge gross cannot be reduced below payments already recorded.
- [x] Headroom check: Payment edit recalculates headroom excluding previous value.
- [x] Payment deletion restores outstanding balance and creates an audit event.
- [x] Monotonic receipt numbers increment sequentially and are never reused after deletion.
- [x] Double-tap protection via in-flight mutation locks in `VaultController`.
- [x] LockScreen obscures sensitive records and requires system authentication.
- [x] Overdue due-date comparisons match local calendar date without timezone shifts.
- [x] Payer deletion blocked when linked charges exist (enforces archiving).
- [x] Zero-net discounted charges settle immediately.
