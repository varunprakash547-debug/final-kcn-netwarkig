# KCN v3 Final Build

Krishi Credit Network (KCN) Flutter/Firebase project prepared as the current consolidated build.

## Main roles

- Farmer: Email + Password login, Aadhaar consent workflow, KCN ID + separate Referral Code, credit summary, products, product groups, orders, network, points/rewards.
- Krishi Kendra: Overview, New Credit, separate Payment, Outstanding, Bill-wise Ledger, KCN Search, back-date request, payment follow-up to Call Center.
- Call Center: Overview, Network Orders, Members, Rewards, Payment Follow-up.
- Super Admin: user approvals/search, products, groups, orders, sales/profit, network tree, payouts, rules, back-date approvals/disable, advertisements, payment corrections, app update controls.

## Important business rules implemented

- Company Cost is Admin-only.
- KCN ID and Referral Code are separate.
- Farmer network tree can grow beyond levels 1/2/3. Reward configuration supports level-specific percentages; current Cloud Function walks up to 20 levels.
- A Krishi Kendra can record a payment only for its own credit.
- Payment cannot exceed current outstanding balance.
- Back-date is separate from Network Rules. Global switch + per-Kendra approval + 7-year boundary are supported.
- Admin can later disable an approved Kendra's back-date permission.
- Network product/order data is separated from Kendra credit/payment data through separate collections and Firestore rules.
- Ads are controlled from Admin; mobile Google Mobile Ads uses test IDs until replaced with the owner's real AdMob IDs.
- In-app update checking uses `app_settings_v3/app_update`; Android updates should be published through Google Play.

## Firebase

The project is configured for `kcn-production`.

Deploy Firestore rules from this project directory:

```powershell
firebase.cmd use kcn-production
firebase.cmd deploy --only firestore:rules
```

Cloud Functions are included for optional server-side inventory/reward processing. Deploying Cloud Functions requires a Firebase billing plan that supports them. Do not deploy Functions if you are intentionally avoiding Blaze; migrate those server operations to the planned GoDaddy PHP/MySQL backend instead.

## Flutter run

```powershell
flutter clean
flutter pub get
flutter run
```

## Android / Play Store

The Android build is prepared to target API 36, which is required for new apps and app updates submitted to Google Play starting August 31, 2026. Google Play new apps use Android App Bundles (AAB).

Build an AAB locally after your signing configuration is ready:

```powershell
flutter build appbundle --release
```

The output is normally under:

`build/app/outputs/bundle/release/`

Every Play Store update must use a higher `versionCode`. Update the `version:` in `pubspec.yaml`, for example `1.0.0+2` -> `1.0.1+3`.

Before production submission:

- Replace AdMob test IDs with your own approved AdMob app/ad-unit IDs.
- Configure Play App Signing/upload key.
- Complete Play Console developer/app verification requirements.
- Add Privacy Policy and Data Safety details.
- Provide a reviewer demo account as required by Play Console.
- Verify account deletion/support requirements for the production app.

## Current bootstrap admin

`varunprakash547@gmail.com`

## Sample product

THAR Company Product

- Company cost: ₹150 (Admin-only)
- Farmer price: ₹300
- Points: 100

## Planned backend migration

If avoiding Firebase Blaze, keep Firebase Authentication as needed and migrate business data/server calculations to the existing GoDaddy PHP 8.3 + MySQL hosting via a secured HTTPS API. Do not expose MySQL credentials in the Flutter app.


Release identity finalized:
- App name: Krishi Credit Network
- Android package/applicationId: in.thekcn.kcn
- Firebase Android app: registered for in.thekcn.kcn
- Note: release signing/keystore still must be configured before Play Store production upload.
