KCN v3 Final Build

Core modules:
- Email + password authentication
- Farmer, Krishi Kendra, Call Center and Super Admin roles
- Farmer Aadhaar hash + last-4 + consent workflow; raw Aadhaar is not stored by the registration client
- KCN credit, payments, ledger, outstanding, public risk summary and farmer consent access requests
- Separate 7-year back-date permission workflow with Kendra request, Admin approve/reject and disable support
- Network products with Admin-only company cost/margin data
- Product edit, technical name, description, photo URL, price, points, active state and stock +/−
- Product groups with group price, description and product quantities
- Farmer group ordering; Cloud Function reserves/decreases stock for both single and group orders
- Network members, points, rewards, sales/profit report and Admin payout recording
- Admin user search, approvals, products, groups, orders, sales, network tree, payouts, rules, back-date and advertisements
- AdMob integration for Android/iOS using test IDs; Web/Desktop use the Firebase-controlled advertisement banner because Google Mobile Ads is mobile-platform only
- Responsive navigation for mobile and desktop/web

Before store launch:
- Replace AdMob test IDs with your real AdMob app/unit IDs.
- Deploy Firestore rules and Cloud Functions to the same Firebase project used by the Flutter app.
- Review Aadhaar/identity flow and the network compensation plan with the appropriate Indian legal/compliance professional before production use.
- Do not delete existing Firebase data.
