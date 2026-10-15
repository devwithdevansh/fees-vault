# FeesVault — macOS & iPhone Handoff Guide

This document outlines the exact, step-by-step instructions for transferring the FeesVault project to a macOS environment, resolving native CocoaPods dependencies, configuring code signing in Xcode, running the app on a physical iPhone, and verifying all iOS platform security controls.

---

## 1. Prerequisites on macOS

Ensure the borrowed Mac has the following tools installed:
- **macOS:** macOS Ventura 13.5+ or Sonoma 14.0+
- **Xcode:** Xcode 15+ (from Mac App Store or Apple Developer portal)
- **Command Line Tools:** `xcode-select --install`
- **CocoaPods:** `sudo gem install cocoapods` or `brew install cocoapods`
- **Flutter SDK:** Stable channel (matches Flutter 3.44.3, Dart 3.12.2)

Verify environment:
```bash
flutter doctor -v
```

---

## 2. Project Transfer & Dependency Installation

1. **Clone or Copy Repository:**
   Transfer the `Fee-vault` directory to your Mac (e.g. `~/Projects/fees_vault`).

2. **Fetch Flutter Dependencies:**
   ```bash
   cd ~/Projects/fees_vault
   flutter clean
   flutter pub get
   ```

3. **Install CocoaPods & SQLCipher:**
   ```bash
   cd ios
   pod install --repo-update
   cd ..
   ```
   *Note:* The Podfile is configured with `platform :ios, '13.0'` and imports SQLCipher natively without normal unencrypted SQLite conflicts.

---

## 3. Xcode Code Signing & Bundle ID Configuration

1. **Open Xcode Workspace:**
   Open the **`.xcworkspace`** file (NOT `.xcodeproj`):
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Configure Signing & Team:**
   - In Xcode's Project Navigator, select the **Runner** project at the top.
   - Select the **Runner** target.
   - Navigate to the **Signing & Capabilities** tab.
   - Select your **Team** (Personal Apple ID or Organization Developer Team).
   - If using a personal free team, update the placeholder **Bundle Identifier** (`com.feesvault.fees_vault`) to a globally unique identifier (e.g., `com.<yourname>.feesvault`).

3. **Verify Info.plist Entitlements & Permissions:**
   In `ios/Runner/Info.plist`, ensure the following are present:
   - `NSFaceIDUsageDescription`: *"FeesVault requires Face ID to protect sensitive financial records and fee management data."*
   - `CFBundleDisplayName`: `FeesVault`
   - `UIFileSharingEnabled`: `false`
   - `LSSupportsOpeningDocumentsInPlace`: `false`

---

## 4. Deploying and Running on a Physical iPhone

1. **Connect iPhone via USB or Wi-Fi:**
   - Unlock the iPhone and tap **Trust This Computer**.
   - On iOS 16+, enable Developer Mode under:
     **Settings > Privacy & Security > Developer Mode > On** (device will reboot).

2. **Build and Run via Flutter CLI:**
   Check connected devices:
   ```bash
   flutter devices
   ```
   Launch directly on the iPhone:
   ```bash
   flutter run -d <your-iphone-device-id> --release
   ```
   *(Or select your physical iPhone in Xcode's target dropdown and click the Play/Run button).*

3. **First-Time Trust (Free Personal Team Only):**
   If prompted with an untrusted developer alert on the iPhone:
   - Go to **Settings > General > VPN & Device Management**.
   - Tap your Apple ID profile and select **Trust**.

---

## 5. iOS Platform Security Acceptance Checklist

Perform the following manual and runtime checks on the physical iPhone:

### A. Biometric & Passcode Gate
- [ ] On first launch, the app prompts for system Face ID / Touch ID / Passcode.
- [ ] If authentication is canceled, the screen remains locked behind the security curtain with a retry action.
- [ ] Passing authentication decrypts and opens the database.

### B. App Switcher Privacy Blur
- [ ] Swipe up halfway into the iOS App Switcher (multitasking view).
- [ ] Verify that the FeesVault window snapshot is covered with a dark blur overlay (`UIVisualEffectView`) and reveals no balances or client names.
- [ ] Returning to FeesVault dismisses the overlay seamlessly.

### C. Background Lock & State Machine
- [ ] Send the app to the background by swiping up to the home screen.
- [ ] Wait 5 seconds and reopen the app.
- [ ] Verify that the database handle was closed safely and the app prompts for Face ID / Passcode before revealing financial records.

### D. Effective NSFileProtectionComplete & Backup Exclusion
- [ ] In **Settings > Vault Security**, inspect the attributes:
  - Cipher: `SQLCipher (AES-256)`
  - Keychain: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (`synchronizable = false`)
  - File Protection: `NSFileProtectionComplete`
  - Backup Exclusion: `isExcludedFromBackup = true`
- [ ] Lock the iPhone screen. File protection ensures file keys are purged from iOS memory while the phone is locked.

### E. Airplane Mode / Offline Proof
- [ ] Put the iPhone into Airplane Mode (Wi-Fi and Cellular off).
- [ ] Add a Payer, record a Charge, and commit a Payment.
- [ ] Force quit and relaunch the app.
- [ ] Verify all entries and receipt numbers persist perfectly without network dependencies.
