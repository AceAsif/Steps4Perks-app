# Steps4Perks - Plan to redesign and monetise

Written: 15 November 2026. Planning only. No app code was changed.
All web sources were read on 15 November 2026. Links are in each section.

## Short answer first

1. **With today's rules the app cannot pay for its rewards from ads.** A user who walks 10,000 steps a day earns about A$12 to A$24 of gift cards a month (if 2,500 points = A$5 to A$10). Ads from that same user bring in about A$0.20 to A$3.75 a month. The gap is 3x to over 100x.
2. **"Watch an ad, get points for gift cards" is not allowed by AdMob.** AdMob says gift cards and cash can never be a reward for a rewarded ad, and points that can be turned into gift cards do not pass either. The planned "Step Booster" (watch 5 ads for 2x points) must be dropped or changed.
3. **Points are not safe today.** The phone decides how many points a user has and writes that number to Firestore. Any user with basic skill can give themselves unlimited points. This must be fixed before any real gift card is ever sent.

The app can still work as a business, but only if: points are worth much less, most rewards are funded by partners (not by you), and gift cards are a small, capped part of the budget.

---

## 1. App audit

### What exists

| Area | What is there |
|---|---|
| Size | About 8,400 lines of Dart in `lib/`. Flutter, Material 3, Provider. |
| Sign in | Email + password with email check, Google Sign-In, forgot password, profile completion (asks age, blocks under 18). |
| Onboarding | Intro pages and a tap-through tutorial on the home screen. |
| Home | Step gauge (goal 10,000), streak card, "points today" card, "Claim 100 points" button. |
| Activity | Weekly and monthly bar charts. |
| Rewards | List from Firestore `rewards_catalogue`, progress bar per reward, Claim button, history tab. |
| Profile | Avatar choice, name, notification settings, sign out. |
| Data | Firebase Auth, Firestore (region australia-southeast2), Storage, FCM, local notifications. |
| Steps | `pedometer` plugin (phone sensor). Google Fit / Health Connect code is only a commented-out stub. |
| Ads | None. `ad_service.dart` is a commented-out mock. No ads package in `pubspec.yaml`. |

### Point rules in the code today

- 1 point per 100 steps, max 100 points a day (so 10,000 steps).
- At 10,000 steps the user can press "Claim" for 100 more points. So the most a user can earn is **200 points a day**.
- A reward can be claimed from 2,500 points. That is about 13 days for a user who always hits 10,000 steps.
- The money value of a reward is only in Firestore. I could not see it. This matters a lot (see section 3).

### What is working

- Auth flow is complete and handles sign out / sign in again.
- Local-first step count with sync to Firestore on a timer and when the app goes to the background.
- The daily bonus claim is checked inside a Firestore transaction, so a double tap does not pay twice.
- Firestore rules stop users reading other users' data. Reward history cannot be edited or deleted by the user.
- Data is stored in Australia.
- 18+ age gate at sign up. This helps with ad and privacy rules.

### What is weak

**Money and trust (most serious)**

1. **Points are decided on the phone.** `SyncManager` writes `totalPoints` to `users/{uid}` and the rules allow the user to write their whole own document. A user can set any number of points. (`lib/services/sync_manager.dart`, `firestore.rules`)
2. **Steps are not checked.** Step counts come from the phone and are trusted. Shaking the phone, or a modified app, earns points.
3. **Redeeming is fake.** `rewardspage.dart` makes a code like `RWD-<time>` on the phone and saves the reward as "completed". No real gift card is bought or sent. There is no stock, no approval, no limit per day.
4. **Possible point bug.** Redeem lowers points on the server, but an older `totalPoints` value still waiting in the sync queue can be written after it and give the points back.
5. **History delete does nothing.** `rewardshistory.dart` tries to delete a history item, but the rules block it.

**Store blockers**

6. Android app id is `com.example.steps4perks` and the release build is signed with the debug key. Google Play will not accept either.
7. Android asks for permissions it does not need: `USE_FULL_SCREEN_INTENT`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `ACCESS_NOTIFICATION_POLICY`, plus `showWhenLocked` and `turnScreenOn`. Google Play limits these to alarm and calling apps. Expect a rejection.
8. iOS `Info.plist` has no `NSMotionUsageDescription`. The app will crash or be rejected when it reads steps on iPhone.
9. No account deletion in the app. Both stores require it.
10. Sign up says "you agree to our Terms & Privacy" but there is no link and no document.
11. iOS offers Google Sign-In with no second privacy-friendly login (Apple guideline 4.8).
12. The SDK line in `pubspec.yaml` points to a beta Dart version.

**Design**

13. Colours do not agree with each other: teal theme, deep orange buttons, deep purple nav, black tab pills, grey cards.
14. Many sizes are a fraction of screen width, so text is too small on small phones and too big on tablets. No dark mode.
15. The rewards screen shows the same "your points / cost" line on every card. It does not show what the reward is worth or how many days of walking it needs.
16. Settings is three "schedule reminder" buttons. No privacy, no help, no account controls.
17. Debug tools and "Add 1000 mock steps" are hidden behind debug mode only. Good, but the debug page should not ship at all.

**Code health**

18. The only test is the default Flutter counter test. It does not match the app and will fail.
19. `StepTracker` is 688 lines and mixes sensor, points, streak, sync and storage. Hard to test.
20. `ios/build/` cache files (about 70 files) are committed. They should be ignored.
21. `syncfusion_flutter_gauges` needs a Syncfusion licence (free community licence or paid). Check you have one, or replace the gauge.
22. Steps taken while the app is closed across midnight, or after a phone restart, can be lost or counted on the wrong day.

### Secrets and keys check

- **No keystore, `.jks`, `.env`, private key or service account file is in the repo or its history.** Good.
- These Firebase client config files are committed: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`. They hold Firebase API keys. These are meant to ship inside the app and are not passwords, but anyone can read them, so: restrict the keys in Google Cloud console, and turn on Firebase App Check. I did not print their contents.
- The AdMob app id in `ios/Runner/Info.plist` is Google's public sample id, not yours.

---

## 2. Redesign

### Goal of the design

One clear daily loop: **open, see today's steps, see how close the next reward is, close.** Under 10 seconds. Everything else is one tap away.

### What to keep, change, drop

| Keep | Change | Drop |
|---|---|---|
| 4 tabs (Home, Activity, Rewards, Profile) | Home becomes "Today" with next-reward progress | "Step Booster: watch 5 ads for 2x" (breaks AdMob rules) |
| Step ring and 10,000 goal | Ring drawn in app code, not Syncfusion | Fake gift card code made on the phone |
| Streaks | Streak shown as a week strip, with one "freeze" a week | Three "schedule reminder" buttons |
| Email + Google sign in, 18+ gate | Add Sign in with Apple on iOS | Debug tools page in release builds |
| Weekly / monthly charts | Add "best day" and average | Avatar picker with 2 stock photos (use initials) |
| Reward history | Add status: Requested, Sent, Failed | "Claim 100 points" button (give the bonus by itself at 10,000 steps) |
| Pull to refresh | One reminder setting with a time picker | Tutorial overlay (replace with 3 clear onboarding cards) |

### Visual style

**Feel:** a calm morning walk. Friendly, clear, a little warm. Not a casino, not a bank. Money is never shouted.

**Colours**

| Role | Light | Dark | Use |
|---|---|---|---|
| Primary (Eucalypt) | `#0F6E5C` | `#5FD3B8` | Step ring, main buttons, active tab |
| Accent (Wattle) | `#F2B01E` | `#F7C948` | Points and rewards only |
| Streak (Ochre) | `#D9541E` | `#F0834F` | Streak flame only |
| Background | `#F6F4EE` | `#101614` | Screen |
| Surface | `#FFFFFF` | `#1A2320` | Cards |
| Text | `#13201C` | `#ECF2EF` | Main text |
| Text soft | `#5C6B66` | `#9DB0A9` | Labels |
| Error | `#B3261E` | `#F2B8B5` | Errors |

Rule: gold means points, everywhere, and nothing else is gold. Green means steps.

**Type**

- Headings and big numbers: **Plus Jakarta Sans** (bold, tabular figures for the step count).
- Body: **Inter**.
- Sizes: 44 (step count), 24 (page title), 18 (card title), 16 (body), 13 (label). Fixed sizes that follow the phone's text size setting, not a fraction of screen width.

**Shape and motion**

- Cards with 20 radius, no heavy shadows, 16 padding, 12 gap.
- Bottom bar: standard Material 3 `NavigationBar` (better for accessibility than the floating pill).
- Motion: the ring fills when steps change, a small gold burst when points are earned. Respect "reduce motion".
- Minimum tap target 48.

### User flow

```
Splash
  -> Welcome (3 cards: Walk / Earn / Redeem, with honest numbers)
  -> Sign up or sign in (Email, Google, Apple on iOS) -> verify email -> age 18+
  -> "Why we need motion access" screen -> system permission
  -> "Reminders?" screen (optional) -> system permission
  -> Today (home)

Today -> Activity (charts)
Today -> Rewards -> Reward detail -> Confirm -> "Requested" -> email with code -> History
Today -> Profile -> Settings (reminder, privacy, ads choice, delete account, help)
```

### Screens in simple words

1. **Welcome.** Three cards. The third one says the truth: "A A$5 gift card takes about X weeks of walking." No big promises.
2. **Sign in / Sign up.** Same as now, cleaner. Links to Terms and Privacy Policy that really open.
3. **Motion permission.** Before the system box, one screen says: "Steps4Perks reads your step count to give you points. We store your daily step total in Australia. We never use your steps for ads." Buttons: Allow / Not now.
4. **Today.** Big ring with steps. Under it: points today, streak week strip, and one card "Next reward: A$5 Coles - 62% - about 9 days". One banner ad at the bottom of the scroll, away from buttons.
5. **Activity.** Week / Month / Year switch, bar chart, three numbers: average, best day, total distance.
6. **Rewards.** Points balance at top with "How points work" link. Two groups: "Partner perks" (discounts, cost you nothing) and "Gift cards" (limited each month, show stock left).
7. **Reward detail.** Picture, value, cost in points, rules, delivery time ("within 3 days by email"), Redeem button. Then a confirm sheet.
8. **History.** Each item has a status chip. Tapping a "Sent" item shows the code with a copy button.
9. **Profile.** Name, initials avatar, lifetime steps, longest streak. List: Reminder, Privacy and data, Ad choices, Help, Terms, Sign out, Delete account.
10. **Privacy and data.** What is stored, download my data, delete my account.

### Wireframes

**Today (home)**

```
+--------------------------------------+
| Good morning, Sam           [ 1,240 ]|  <- gold points pill
|                                      |
|            .-''''''''-.              |
|          /     6,482    \            |  <- green ring, 65%
|         |      steps     |           |
|          \  of 10,000   /            |
|            '-........-'              |
|                                      |
|  +65 points today      Streak 4 days |
|  M  T  W  T  F  S  S                 |
|  *  *  *  *  o  .  .                 |
|                                      |
| +----------------------------------+ |
| | NEXT REWARD                      | |
| | A$5 Coles gift card              | |
| | [=============-------] 62%       | |
| | about 9 more days                | |
| +----------------------------------+ |
|                                      |
| [           banner ad              ] |
+--------------------------------------+
|  Today   Activity   Rewards   Profile|
+--------------------------------------+
```

**Rewards**

```
+--------------------------------------+
| Rewards                              |
| 1,240 points      How points work >  |
|                                      |
| [ Available ]  [ My rewards ]        |
|                                      |
| PARTNER PERKS                        |
| +----------------------------------+ |
| | [logo] 15% off Local Runner      | |
| | 300 points            [ Get ]    | |
| +----------------------------------+ |
| +----------------------------------+ |
| | [logo] Free coffee, Bean St      | |
| | 500 points            [ Get ]    | |
| +----------------------------------+ |
|                                      |
| GIFT CARDS        12 left this month |
| +----------------------------------+ |
| | [logo] A$5 Coles                 | |
| | 30,000 points                    | |
| | [===-----------------] 4%        | |
| +----------------------------------+ |
+--------------------------------------+
```

**Reward detail and confirm**

```
+--------------------------------------+
| <  A$5 Coles gift card               |
|                                      |
|        [   card picture   ]          |
|                                      |
| Cost            30,000 points        |
| You have        31,150 points        |
| Delivery        by email, in 3 days  |
| Valid           3 years              |
|                                      |
| Rules                                |
| - One gift card per month            |
| - We check step history first        |
|                                      |
| [          Redeem reward           ] |
+--------------------------------------+

   confirm sheet:
+--------------------------------------+
| Spend 30,000 points?                 |
| Send to: s***@gmail.com              |
| [ Cancel ]            [ Confirm ]    |
+--------------------------------------+
```

**Activity**

```
+--------------------------------------+
| Activity                             |
| [ Week ] [ Month ] [ Year ]          |
|                                      |
| 12k|          #                      |
| 10k|- - - # - # - - - - - goal       |
|  8k|   #  #   #   #                  |
|  4k| # #  #   #   #  #               |
|    +---------------------            |
|      M T  W   T   F  S  S            |
|                                      |
| Average      Best day     Distance   |
| 7,310        12,480       36.2 km    |
|                                      |
| This week you earned 412 points      |
+--------------------------------------+
```

**Motion permission (before the system box)**

```
+--------------------------------------+
|                                      |
|            ( walking icon )          |
|                                      |
|   Let Steps4Perks count your steps   |
|                                      |
|  - We read your step count to give   |
|    you points.                       |
|  - We store your daily total in      |
|    Australia.                        |
|  - We never use your steps for ads   |
|    and never sell them.              |
|                                      |
|  [            Allow              ]   |
|             Not now                  |
|        Read the privacy policy       |
+--------------------------------------+
```

**Profile**

```
+--------------------------------------+
|  (SA)  Sam A.                        |
|        Member since Mar 2026         |
|                                      |
|  Lifetime steps      Longest streak  |
|  1,204,330           21 days         |
|                                      |
|  Daily reminder            7:30 am > |
|  Privacy and my data               > |
|  Ad choices                        > |
|  Help and contact                  > |
|  Terms and rules                   > |
|  Sign out                            |
|  Delete my account                   |
+--------------------------------------+
```

---

## 3. Monetisation

### 3.1 What AdMob pays (eCPM)

eCPM = income per 1,000 ad views, in US dollars. Google does not publish a table. All numbers below are from benchmark sites that do not agree with each other. **Treat them as rough.** Your own AdMob report is the only true number.

| Format | Australia | USA | India | Source note |
|---|---|---|---|---|
| Banner | $0.25 - $1.00 | $0.50 - $1.50 | under $0.20 | [maf.ad](https://maf.ad/en/blog/mobile-ads-ecpm/), [Playwire](https://www.playwire.com/blog/admob-ecpm-benchmarks-what-publishers-should-expect) |
| Interstitial | $4 - $9 (one source says up to $16 on iOS) | $10 - $23 | $0.80 - $1.50 | [maf.ad](https://maf.ad/en/blog/mobile-ads-ecpm/), [appadrevenue](https://www.appadrevenue.com/guides/how-much-do-mobile-ads-pay), [Playio](https://blog.playio.co/mobile-game-ecpm-benchmarks-2026) |
| Rewarded video | $8 - $20 (one average: $13.80) | $13 - $30 | $1 - $3 | [maf.ad](https://maf.ad/en/blog/mobile-ads-ecpm/), [Business of Apps](https://www.businessofapps.com/ads/rewarded-video/), [Playio](https://blog.playio.co/rewarded-ad-benchmarks-2026), [RevenueLab](https://www.revenuelab.fyi/blog/admob-ecpm-benchmarks-2026) |

Notes: the maf.ad page was over a year old when read. Most of these numbers come from games. A utility app like this one often gets less.

### 3.2 Ad income per active user per day

A walking app is opened a few times a day for a short time. That means few ad views. My assumptions for an Australian user (USD, then A$ at 1 USD = A$1.50, an assumption):

| Case | Banner views x eCPM | Interstitials x eCPM | Rewarded x eCPM | Income per user per day | Per month |
|---|---|---|---|---|---|
| Low | 4 x $0.25 | 0.5 x $4 | 0.2 x $8 | US$0.005 = **A$0.007** | A$0.21 |
| Medium | 10 x $0.50 | 1.5 x $8 | 0.5 x $13 | US$0.024 = **A$0.035** | A$1.06 |
| High | 20 x $1.00 | 3 x $12 | 1.5 x $18 | US$0.083 = **A$0.125** | A$3.75 |

These assume every ad request is filled. Real fill is lower. A new app with few users usually sits between Low and Medium.

### 3.3 What a user earns today

Value of points is not in the repo, so I show two guesses: 2,500 points = A$5, and 2,500 points = A$10.

| User | Points per day | Cost per day if 2,500 = A$5 | Cost per day if 2,500 = A$10 | Cost per month |
|---|---|---|---|---|
| Light (3,000 steps) | 30 | A$0.06 | A$0.12 | A$1.80 - A$3.60 |
| Typical (6,000 steps) | 60 | A$0.12 | A$0.24 | A$3.60 - A$7.20 |
| Full (10,000 + bonus) | 200 | A$0.40 | A$0.80 | A$12 - A$24 |

### 3.4 Does it pay for itself?

| | Income per user per day | Cost of a typical user | Cost of a full user | Result |
|---|---|---|---|---|
| Low | A$0.007 | A$0.12 - A$0.24 | A$0.40 - A$0.80 | Loses 17x to 114x |
| Medium | A$0.035 | A$0.12 - A$0.24 | A$0.40 - A$0.80 | Loses 3x to 23x |
| High | A$0.125 | A$0.12 - A$0.24 | A$0.40 - A$0.80 | About even for a typical user at A$5, loses 3x to 6x on a full user |

**Clear answer: no. With today's point rules, ads cannot pay for the gift cards, in any case.** The best users (who walk the most) are the ones who lose you the most money, and they are also the users who use the app the least time per day.

Some points will never be redeemed (people stop using the app). This helps, maybe a lot, but you cannot plan a business on it, and under Australian consumer law you must be able to honour what you promised.

### 3.5 What the numbers must be to break even

If half of ad income goes to rewards (the other half pays Firebase, fees, tax and you), and an average user earns 100 points a day:

| Case | Reward budget per user per day | Days of walking for one A$5 card | Points a A$5 card must cost |
|---|---|---|---|
| Low | A$0.0035 | about 1,430 days | about 143,000 |
| Medium | A$0.0175 | about 286 days | about 28,600 |
| High | A$0.0625 | about 80 days | about 8,000 |

So a A$5 card should cost roughly **30,000 points, not 2,500** (about 12x more). That matches what other apps really pay: review sites report about US$0.50 to US$3 a month from most walking apps, and around US$15 for a WeWard cash-out after a long time ([householdmoneysaving.com](https://www.householdmoneysaving.com/paid-for-walking-apps/), [finder.com](https://www.finder.com/make-money-online/how-to-get-paid-to-walk), [dualmedia.com](https://www.dualmedia.com/earn-money-while-walking-top-apps-that-pay-you-to-step-up)). These are blog numbers, not audited.

### 3.6 Important AdMob limit

AdMob's rewarded ad policy says ([source](https://support.google.com/admob/answer/7313578)):

- Cash, crypto and **gift cards** are "direct monetary items" and can never be a reward.
- Points are allowed only if they are used inside your app, cannot be passed to others, and cannot be turned into direct monetary items.

So: **a rewarded ad cannot give points that later buy a gift card.** A rewarded ad may give things with no money value: a streak freeze, a theme, a badge, an extra chart.

Paying points for *walking* while the app also shows banner and interstitial ads is a different thing, because the reward is for steps and not for ads. Many walking apps do this. I could not load the AdMob page that covers paying users to view ads (it returned an error), so this part is **not verified**. Also be aware that "get paid" apps attract fake traffic, and AdMob often limits ad serving for them.

### 3.7 Other income, ranked for this app

| Option | How it works | Realistic income | Fit |
|---|---|---|---|
| **Partner perks** | Local or online shops give a discount or free item. Users spend points on it. It costs you nothing. Later, shops pay for placement. | A$0 at first; A$50-A$500 a month per paying partner later | Best. Fixes the cost problem. It is also what the app name says: perks. |
| **Affiliate offers** | "Sign up to X, get 5,000 points." The brand pays you A$5-A$50 per sign up, you give part back as points. | Much more than ads per action, but few actions | Good. Uses networks like Commission Factory or Impact. Not verified for a new small app. |
| **Monthly prize draw** | Fixed budget (for example 10 x A$10 cards a month). Points buy entries. | Not income, but makes cost fixed and known | Good, but each Australian state has trade promotion rules and some need a permit. Get advice first. |
| **Premium plan** | A$3.99 a month: no ads, more charts, streak repair, themes. Do **not** sell extra points. | If 1-2% of users pay: A$0.04-A$0.08 per user per month, after store fee | OK. Small but clean. |
| **Sponsored challenges** | A brand pays for "Walk 50 km in June" with its own prizes. | A$200-A$2,000 per challenge once you have users | Good later (needs 5,000+ users). |
| **Workplace wellness** | A company pays per staff member for a team step challenge. | A$1-A$3 per staff member per month | Good later. Different product, slow sales. |
| **Offerwalls** | Users do tasks (install apps, surveys) for points. | High per user | Risky. Apple dislikes it, brings fraud. Avoid for now. |
| **Selling data** | Selling step data. | - | No. Banned by both stores and bad under privacy law. |

Gift card supply: Prezzee has an Australian business API (its account is free, API is an enterprise feature; smallest consumer card seen is A$5) ([Prezzee](https://prezzee.com/business/m/en-au/api-overview)). Tremendous says its platform and API are free and you pay only for the rewards ([Tremendous](https://www.tremendous.com/gift-card-api/)); I could not confirm its A$ options. For the first months, buying cards by hand is fine.

### 3.8 The model I recommend

1. Points have a low, honest value. Show users the real time needed.
2. Most rewards are partner perks (cost A$0).
3. Gift cards are a small monthly pool with a hard budget cap ("12 left this month"). When the pool is empty, it is empty.
4. Ads: one banner on Today and Activity, one interstitial a day at most (after closing the reward history, never on app open), rewarded ads only for non-money extras.
5. Add premium later, when there are users who would pay to remove ads.

**Budget rule:** reward spend each month is never more than 50% of last month's income. Start with a fixed A$50 a month from your own pocket while testing, and treat it as marketing cost.

Example at 1,000 daily users, Medium case: ad income about A$1,060 a month. Reward budget A$530 = about 100 A$5 cards. Firebase cost for 1,000 users is small if the 1-minute sync is slowed down.

---

## 4. Rules and risks

Not legal advice. For the Privacy Act and prize draws, pay for one hour with a lawyer before launch.

### 4.1 AdMob

| Rule | What it means for you | Source |
|---|---|---|
| Gift cards and cash can never be a rewarded ad reward. Points must not be convertible to them. | Drop Step Booster as designed. | [AdMob rewarded policy](https://support.google.com/admob/answer/7313578) |
| The user must choose to watch a rewarded ad, and must see the reward before it. | Clear "Watch ad for a streak freeze" button. | Same |
| Interstitials only at natural breaks. Not too many. Not the main focus of the app. | Max one a day, never on open or exit. | [AdMob interstitial guidance](https://support.google.com/admob/answer/6066980) |
| Paying users to view or click normal ads | **Not verified.** The policy page did not load. Read it yourself before adding ads. Never tell users to tap ads. | - |

### 4.2 Google Play

| Rule | What it means for you | Source |
|---|---|---|
| Loyalty programs in non-game apps: allowed. Official rules must be in the app. Earn and redeem ratios must be shown clearly. Chance-based rewards need odds or selection method. | Add a "How points work" page and program rules. The policy is written for programs tied to a purchase; it does not say how a walking-only program is treated. Unclear, but other walking apps are on Play. | [Play gambling and loyalty policy](https://support.google.com/googleplay/android-developer/answer/9877032) |
| Every developer must fill in the Health apps declaration. Apps with health features need a privacy policy in Play Console and in the app. | Do the declaration. Write the policy. | [Play health content policy](https://support.google.com/googleplay/android-developer/answer/16679511) |
| Health data is "personal and sensitive". Never sell it. Clear in-app disclosure and a real "yes" before collecting. | Add the motion permission screen from section 2. | [Play user data policy](https://support.google.com/googleplay/android-developer/answer/10144311) |
| Account deletion must be possible in the app **and** from a web page. | Build both. | Same |
| Health and fitness data must not be used for ads or given to ad platforms. "Rewards" for healthy habits is an approved use of Health Connect. | Never send step counts to AdMob or use them for ad targeting. Health Connect is open to you later. | [Play health permissions FAQ](https://support.google.com/googleplay/android-developer/answer/12991134) |
| No surprise full-screen ads. No repeated interstitials. Rewarded ads must be opt-in. | Same ad plan as above. | [Play ads policy](https://support.google.com/googleplay/android-developer/answer/9857753) |

### 4.3 Apple App Store

Guidelines last updated 16 October 2026 ([source](https://developer.apple.com/app-store/review/guidelines/)).

| Guideline | What it means for you |
|---|---|
| 5.1.3 and 2.5.18 | Health and fitness data cannot be used for ads or marketing. No targeted ads from health data. No health data in iCloud. |
| 5.1.2(i) | You may not require users to turn on system features (tracking, notifications, location) to get gift cards or other payment. **Risk:** never tie points to allowing ad tracking or notifications. Motion access is the core feature, but explain this in review notes. |
| 5.1.1(i), (v) | Privacy policy in the app. Account deletion in the app. |
| 5.1.2(i) | Ask with App Tracking Transparency before any tracking. Offer non-personalised ads. |
| 4.8 | If Google Sign-In is offered, also offer another login that hides email (Sign in with Apple does this). |
| 3.2.2(x) | Rewarding a user for watching an ad is allowed. |
| 3.2.2(iii) | Apps made mainly to show ads are not allowed. |
| 5.3.1, 5.3.2 | A prize draw must be run by you, with rules in the app that say Apple is not involved. |
| 3.1.1 | Gift cards for digital goods sold in the app need in-app purchase. The guidelines do not say anything about free points redeemed for shop gift cards. Expect a question from the reviewer. Do not sell points. |
| 1.4.1 | Make no medical claims about steps. |

### 4.4 Australian privacy law

I could not open the OAIC and Attorney-General pages (they blocked automated reading), so this part uses law firm and news summaries. Check the OAIC site yourself.

| Point | Status | Source |
|---|---|---|
| Small businesses under A$3 million a year are mostly exempt from the Privacy Act. There are exceptions, for example businesses that handle health information in some ways or trade in personal information. | Still in force on the sources I found. Removal has been proposed but has no start date. Whether step counts count as "health information" is **not verified**. | [Sprintlaw](https://sprintlaw.com.au/articles/privacy-law-reforms-small-business/), [Solway, 13 Oct 2026](https://solway.au/blog/privacy-act-december-2026-small-business-exemption/) |
| A person can sue for a serious invasion of privacy. This applies even if you are exempt from the Privacy Act. | In force since 10 June 2025. | [Norton Rose Fulbright](https://www.nortonrosefulbright.com/en/knowledge/publications/87ee5e95/privacy-gets-teeth-australias-new-statutory-tort-and-how-it-might-look-in-practice), [Corrs](https://www.corrs.com.au/insights/australias-ongoing-privacy-reforms-bolstering-australias-privacy-regulatory-framework) |
| Children's Online Privacy Code | Due to be registered by 10 December 2026. Keep the 18+ gate. | [Corrs](https://www.corrs.com.au/insights/australias-ongoing-privacy-reforms-bolstering-australias-privacy-regulatory-framework), [Digital Rights Watch](https://digitalrightswatch.org.au/2025/06/09/2025-privacy-reform-explainer/) |

**What to do anyway** (the stores require most of it): act as if the Privacy Act applies. Collect only email, name, age check and daily step totals. Stop storing exact age; store "over 18: yes". Keep data in Australia. Write a plain privacy policy. Give download and delete. Have a plan for a data breach.

### 4.5 Australian consumer law

- Gift cards sold in Australia must last at least 3 years. Cards given free in a loyalty program may be exempt, but check each card's terms ([consumer.gov.au](https://consumer.gov.au/node/161), [Corrs](https://www.corrs.com.au/insights/new-laws-to-affect-businesses-that-issue-gift-cards)).
- Do not mislead. If the app says "earn gift cards", a normal user must really be able to get one. Show real times. If you change point values, give notice (for example 30 days) and say so in the rules.
- Points are a debt you owe. Put an expiry in the rules (for example 12 months with no activity) and a monthly cap.

### 4.6 Biggest risks

| Risk | How likely | How bad | What to do |
|---|---|---|---|
| Users cheat points (edit Firestore, shake phone) | Sure, once rewards are real | Very bad: direct money loss | Server-side points, App Check, daily caps, manual check before each gift card |
| Reward cost grows faster than income | Sure with today's rules | Very bad | Monthly pool with hard cap, new point values |
| AdMob account limited or closed | Medium for reward apps | Bad | No ad-for-points, low ad load, no click hints |
| Store rejection | High on first try | Medium | Fix section 1 blockers first, write clear review notes |
| Users angry when point value drops | Medium | Medium | Change values before public launch, not after |

---

## 5. Roadmap

Usage: **S** = small (under 1 hour of AI work), **M** = medium (a few hours), **L** = large (a day or more, many files).
Model: **Haiku** for simple edits, **Sonnet** for normal feature work, **Opus or Fable** for security, money logic and hard design. This is my suggestion; any step can be done on a stronger model.

### Phase 0 - Decide (you, no code)

| # | Step | Usage | Model |
|---|---|---|---|
| 0.1 | Answer the open questions in section 6 | - | you |
| 0.2 | Pick point value and monthly reward budget | S | Sonnet (spreadsheet help) |

### Phase 1 - Make it safe and honest

| # | Step | Usage | Model |
|---|---|---|---|
| 1.1 | Remove `ios/build/` from git and add to `.gitignore` | S | Haiku |
| 1.2 | Replace the default test with real unit tests for point and streak rules | M | Sonnet |
| 1.3 | Split `StepTracker` into small parts (sensor, points, streak, sync) | L | Opus/Fable |
| 1.4 | Cloud Function: server works out points from step totals, with daily caps | L | Opus/Fable |
| 1.5 | Firestore rules: user cannot write `totalPoints`, streak or reward status | M | Opus/Fable |
| 1.6 | Cloud Function: redeem request (check balance, stock, monthly cap; status "requested") | L | Opus/Fable |
| 1.7 | Turn on Firebase App Check and restrict the API keys | S | Sonnet |
| 1.8 | Simple fraud checks: max steps per hour, flag odd accounts, admin approve list | M | Opus/Fable |
| 1.9 | Fix midnight and phone-restart step counting | M | Sonnet |

### Phase 2 - Store blockers

| # | Step | Usage | Model |
|---|---|---|---|
| 2.1 | Real app id and release signing (you create the keystore; never commit it) | S | Sonnet |
| 2.2 | Remove unneeded Android permissions and lock-screen flags | S | Haiku |
| 2.3 | Add iOS motion usage text | S | Haiku |
| 2.4 | Account deletion in app + web page + Cloud Function that wipes data | M | Sonnet |
| 2.5 | Privacy policy, terms, program rules pages (hosted) and links in app | M | Sonnet (text), lawyer check |
| 2.6 | Sign in with Apple on iOS | M | Sonnet |
| 2.7 | Move off the beta Dart SDK line | S | Haiku |
| 2.8 | Store "over 18" instead of exact age | S | Haiku |

### Phase 3 - Redesign

| # | Step | Usage | Model |
|---|---|---|---|
| 3.1 | New theme: colours, type, light and dark | M | Sonnet |
| 3.2 | Shared widgets: card, button, points pill, progress bar | M | Sonnet |
| 3.3 | Today screen with own ring painter and next-reward card | L | Opus/Fable |
| 3.4 | Activity screen | M | Sonnet |
| 3.5 | Rewards list, detail, confirm, history with status | L | Sonnet |
| 3.6 | Profile and settings, single reminder picker | M | Sonnet |
| 3.7 | New onboarding and permission screens, remove tutorial overlay | M | Sonnet |
| 3.8 | Accessibility pass: text scaling, contrast, screen reader labels | S | Sonnet |

### Phase 4 - Money

| # | Step | Usage | Model |
|---|---|---|---|
| 4.1 | Add ads SDK with consent and iOS tracking prompt, test ids only | M | Sonnet |
| 4.2 | Banner on Today and Activity | S | Haiku |
| 4.3 | One-a-day interstitial with a server-controlled switch | S | Sonnet |
| 4.4 | Rewarded ad for streak freeze (no points) | M | Sonnet |
| 4.5 | Partner perks in the catalogue (code or link rewards) | M | Sonnet |
| 4.6 | Monthly gift card pool with stock count and budget cap | M | Opus/Fable |
| 4.7 | Analytics: daily users, points given, points redeemed, ad income per user | M | Sonnet |

### Phase 5 - Launch and grow

| # | Step | Usage | Model |
|---|---|---|---|
| 5.1 | Closed test with 20-50 people for 4 weeks. Measure real ad income per user. | S | you + Sonnet |
| 5.2 | Re-run section 3 with real numbers. Change point values before public launch. | S | Opus/Fable |
| 5.3 | Store listings, screenshots, health declaration, data safety form | M | Sonnet |
| 5.4 | Health Connect / HealthKit as a second step source | L | Opus/Fable |
| 5.5 | Premium plan | L | Sonnet |
| 5.6 | Gift card API in place of buying by hand | M | Opus/Fable |
| 5.7 | Sponsored challenges and prize draw (after legal advice) | L | Opus/Fable |

Do Phase 1 before anything else. The redesign has no value if points can be forged.

---

## 6. Open questions and assumptions

### Questions for you

1. What is in `rewards_catalogue` now? What is a 2,500-point reward worth in dollars?
2. Has anyone redeemed a real gift card yet? Do current users have point balances that you must honour?
3. How much of your own money can you put into rewards each month while testing?
4. Android only at first, or iPhone too? (iPhone adds Sign in with Apple, tracking prompt and a stricter review.)
5. Australia only, or other countries? (Ad income in India is about one tenth of Australia.)
6. Do you have an ABN or company? Is yearly income under A$3 million?
7. Are you happy for gift cards to become a small, capped part and partner perks the main reward?
8. Do you know any local shops that would give a discount as a first partner?
9. Do you have a Syncfusion licence?
10. May the 10,000-step "Claim" button go away (bonus given by itself)?
11. Is the `branch/ios` branch still needed, or is `main` the only truth?

### Assumptions I made

- Target market is Australia first (Firestore is in Australia, age gate is 18+).
- 2,500 points is worth A$5 to A$10. If it is worth less, the loss is smaller but still a loss.
- 1 USD = A$1.50.
- Ad views per user per day are my estimates for a short-session app, not measured.
- eCPM numbers are from third-party sites, mostly games, and will be lower for a new app.
- Reward budget is 50% of ad income.
- You are one developer with a small budget, so I chose steps that need little money up front.
- No app code, dependencies, Firebase settings or keys were changed for this plan.

### What I could not verify

- AdMob's rule on paying users while showing normal (non-rewarded) ads: page did not load.
- OAIC and Attorney-General pages: blocked. Privacy section uses secondary sources.
- Whether step counts are "health information" under the Privacy Act.
- Gift card API fees and smallest card value in A$ for business accounts.
- State rules and permit limits for prize draws.
