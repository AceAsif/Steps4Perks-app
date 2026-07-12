# Steps4Perks 👟🎁

A Flutter app that rewards you for walking. Track your daily steps with your phone's pedometer, earn points, build streaks, and redeem points for gift card rewards.

## Features

- **Step tracking** — live daily step counts via the device pedometer sensor, with a radial gauge and weekly/monthly bar charts
- **Points system** — earn 1 point per 100 steps (capped at 100 points/day), plus a claimable daily bonus at 10,000 steps
- **Streaks** — hit 10k steps daily to build and maintain a streak
- **Rewards** — redeem accumulated points (2,500 minimum) for gift cards, with full redemption history
- **Offline-first** — steps and points persist locally in SharedPreferences and sync to Firestore on a timer and on app lifecycle events
- **Auth** — email/password with verification, plus Google Sign-In
- **Notifications** — local scheduled reminders and Firebase Cloud Messaging support

## Tech stack

| Layer | Tech |
|---|---|
| Framework | Flutter (Material 3) |
| State management | Provider (`ChangeNotifier`) |
| Backend | Firebase Auth, Cloud Firestore, Firebase Storage, FCM |
| Sensors | `pedometer`, `permission_handler` |
| Charts | `fl_chart`, `syncfusion_flutter_gauges` |

## Project structure

```
lib/
├── features/       # Core domain logic (StepTracker) + composite widgets
├── models/         # Firestore data models
├── services/       # Firebase, pedometer, notifications, sync, auth
├── theme/          # Colors, text styles, app theme
├── utils/          # StreakManager
├── view/           # Pages (home, activity, rewards, profile, auth)
└── widgets/        # Reusable UI components
```

## Getting started

1. Install Flutter (stable channel) and run `flutter pub get`
2. Set up a Firebase project and run `flutterfire configure` to generate `firebase_options.dart`
3. Deploy the Firestore security rules: `firebase deploy --only firestore:rules`
4. Run on a **physical device** (the pedometer sensor is unavailable on emulators): `flutter run`

## Firestore data model

```
users/{uid}
├── totalPoints, currentStreak, name, email, onboardingComplete, ...
├── dailyStats/{yyyy-MM-dd}     # steps, dailyPointsEarned, streak, claimedDailyBonus
└── redeemed_rewards/{id}       # redemption history (create-only)

rewards_catalogue/{id}          # read-only rewards, managed via console
```
