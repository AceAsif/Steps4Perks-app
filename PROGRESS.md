# Progress - Redesign and monetisation plan
Branch: plan/redesign-and-monetise
Last updated: 2026-11-15

## Done
- Step 1: Made branch plan/redesign-and-monetise from main.
- Step 2: Read the app code (lib/, Android and iOS config, Firestore rules, pubspec).
- Step 3: Searched the web for AdMob, Google Play, Apple and Australian rules, and for AdMob eCPM numbers.
- Step 4: Wrote docs/PLAN.md (audit, redesign, monetisation, rules, roadmap, open questions).

## In progress
- Nothing.

## Next step
- The user reads docs/PLAN.md and answers the open questions in section 6.
- After that, start roadmap Phase 1 (step 1.1) on a new feature branch. Do not start before the user agrees.

## Decisions
- Planning only. No app code, dependencies, Firebase settings or keys were changed.
- Tests were not run, because no code changed. The only test in the repo is the default Flutter counter test, which does not match the app and is expected to fail.
- Used A$5 to A$10 as the guess for the value of 2,500 points, because the real value is only in Firestore.
- Used 1 USD = A$1.50 and my own estimates for ad views per user per day.
- eCPM numbers are from third-party benchmark sites. Google does not publish them.

## Problems / questions for the user
- See docs/PLAN.md section 6 for the full list.
- Could not open OAIC and Attorney-General pages (blocked), so the Privacy Act part uses law firm summaries.
- Could not open the AdMob page about paying users while showing normal ads. Not verified.
- No keystore or secret file is committed. Firebase client config files (google-services.json, GoogleService-Info.plist, firebase_options.dart) are committed; they hold public client API keys that should be restricted in Google Cloud console.
