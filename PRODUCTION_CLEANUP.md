# KCN Production Cleanup

Before publishing, remove only test/demo records from Firebase after confirming they are not real customer records. Do not delete production accounts or financial records blindly.

## Test identifiers intentionally removed from the app source
- Google sample AdMob app/unit IDs
- Welcome/demo advertisement seeding
- Demo THAR product seeding
- Old Play Store package URL

Real AdMob IDs are not configured in this build; Ads remain inactive until KCN production AdMob IDs are supplied.

## Public legal URLs
- https://thekcn.in/privacy-policy.html
- https://thekcn.in/terms.html
- https://thekcn.in/delete-account.html
- https://thekcn.in/support.html
- https://thekcn.in/about.html
