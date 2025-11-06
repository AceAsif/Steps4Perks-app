import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/features/profile_image_provider.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/services/profile_image_service.dart';
import 'package:myapp/services/sync_manager.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/view/onboardingpage.dart';
import 'package:myapp/view/auth/login_page.dart';
import 'package:myapp/view/auth/signup_page.dart';
import 'package:myapp/view/auth/verification_page.dart';
import 'package:myapp/view/auth/profile_completion_page.dart';
import 'package:myapp/features/bottomnavigation.dart';

final NotificationService notificationService = NotificationService();
final SyncManager syncManager = SyncManager();
final DatabaseService databaseService = DatabaseService();

@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🔔 Background message: ${message.messageId}");
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(
    NotificationResponse notificationResponse) {
  debugPrint(
      '🔔 Local Background Notification tapped → Payload: ${notificationResponse.payload}');
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint(
      '🔔 Local Notification tapped! Payload: ${notificationResponse.payload}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized.');

  try {
    tz.initializeTimeZones();
    debugPrint('✅ Timezones initialized.');
  } catch (e) {
    debugPrint('❌ Timezone init error: $e');
  }

  try {
    await notificationService.initialize();
    debugPrint('✅ NotificationService initialized.');
  } catch (e) {
    debugPrint('❌ NotificationService init error: $e');
  }

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _syncTimer;
  AppLifecycleState? _lastLifecycleState;

  @override
  void initState() {
    super.initState();

    // 🟢 Use WidgetsBindingObserver for reliable lifecycle handling
    WidgetsBinding.instance.addObserver(this);

    // 🟢 1-min timer while app is open
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        debugPrint('⏲️  SyncManager: Periodic sync (1 min interval)...');
        syncManager.syncNow();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    debugPrint('🛑 SyncManager: Timer canceled');
    super.dispose();
  }

  /// 🟢 CRITICAL: This fires on all lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    debugPrint('📱 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('🟢 App RESUMED - forcing sync of pending data...');
        _onAppResume();
        break;

      case AppLifecycleState.paused:
        debugPrint('🟡 App PAUSED (background) - sync if needed');
        _onAppPaused();
        break;

      case AppLifecycleState.detached:
        debugPrint('🔴 App DETACHED - FINAL SYNC BEFORE CLOSE!');
        _onAppDetached();
        break;

      case AppLifecycleState.hidden:
        debugPrint('⚫ App HIDDEN');
        break;

      case AppLifecycleState.inactive:
        debugPrint('⚪ App INACTIVE');
        break;
    }
  }

  /// 🟢 When user opens app - complete sync
  Future<void> _onAppResume() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️  No user to sync on resume');
        return;
      }

      // Step 1: Sync via SyncManager only - DON'T access providers yet!
      await syncManager.syncNow(forceWrite: true);
      debugPrint('✅ SyncManager sync complete on resume');

      // Step 2: Wait a moment
      await Future.delayed(const Duration(milliseconds: 500));

      // ❌ REMOVE the daily stats sync from here!
      // The 2-min timer will handle it, plus onPause and onDetach

    } catch (e) {
      debugPrint('❌ Error on app resume: $e');
    }
  }


  /// 🟡 When app goes to background
  Future<void> _onAppPaused() async {
    try {
      await syncManager.syncNow();
      debugPrint('✅ Background sync complete');
    } catch (e) {
      debugPrint('❌ Error on app pause: $e');
    }
  }

  /// 🔴 CRITICAL: When app is about to close - FINAL SYNC
  Future<void> _onAppDetached() async {
    debugPrint('🔴 FINAL SYNC BEFORE APP CLOSES...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️  No user, skipping detach sync');
        return;
      }

      // Force sync ALL pending data
      final syncSuccess = await syncManager.syncNow(forceWrite: true);

      if (syncSuccess) {
        debugPrint('✅ DETACH SYNC: Successfully synced to Firebase');
      } else {
        debugPrint('⚠️  DETACH SYNC: Sync had issues but continuing');
      }

      // Give Firebase a moment to complete writes
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('✅ FINAL SYNC COMPLETE - App can now close safely');
    } catch (e) {
      debugPrint('❌ DETACH SYNC ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StepTracker()),
        ChangeNotifierProvider(create: (_) => ProfileImageProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Steps4Perks',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignupPage(),
          '/onboarding': (context) => const OnboardingPage(),
          '/home': (context) => const Bottomnavigation(title: 'Steps4Perks'),
          '/verify': (context) => const VerificationPage(),
          '/complete-profile': (context) => const ProfileCompletionPage(),
        },
      ),
    );
  }
}

/// AuthGate - handles authentication state
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        debugPrint(
            '🔄 AuthGate: Connection state = ${authSnapshot.connectionState}');

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          final user = authSnapshot.data!;
          debugPrint('✅ AuthGate: User logged in = ${user.email}');
          return UserPageRouter(user: user);
        }

        debugPrint('⚠️ AuthGate: No user, showing LoginPage');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _clearAllProvidersSync(context);
        });

        return const LoginPage();
      },
    );
  }

  void _clearAllProvidersSync(BuildContext context) {
    try {
      final stepTracker = context.read<StepTracker>();
      final profileImageProvider = context.read<ProfileImageProvider>();

      stepTracker.clear();
      profileImageProvider.clear();
      ProfileImageService.clearAll();

      debugPrint('🧹 All providers cleared on logout');
    } catch (e) {
      debugPrint('⚠️ Could not clear providers: $e');
    }
  }
}

/// UserPageRouter
class UserPageRouter extends StatefulWidget {
  final User user;

  const UserPageRouter({
    super.key,
    required this.user,
  });

  @override
  State<UserPageRouter> createState() => _UserPageRouterState();
}

class _UserPageRouterState extends State<UserPageRouter> {
  bool _providersLoaded = false;
  String? _loadedForUid;
  late StreamSubscription<User?> _authStateSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProvidersForUser(widget.user.uid);
      }
    });

    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (mounted && user != null && user.uid == widget.user.uid) {
            debugPrint(
                '🔄 Auth state updated: emailVerified = ${user.emailVerified}');

            user.reload().then((_) {
              final freshUser = FirebaseAuth.instance.currentUser;
              if (freshUser != null && mounted) {
                setState(() {
                  debugPrint('✅ UserPageRouter: Rebuilt');
                });
              }
            });
          }
        });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UserPageRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _loadProvidersForUser(widget.user.uid);
    }
  }

  Future<void> _loadProvidersForUser(String uid) async {
    if (!mounted) return;

    if (_loadedForUid == uid && _providersLoaded) {
      return;
    }

    setState(() {
      _providersLoaded = false;
      _loadedForUid = uid;
    });

    try {
      debugPrint('🔄 Loading providers for user: $uid');

      if (mounted) {
        context.read<StepTracker>().clear();
        context.read<ProfileImageProvider>().clear();
      }

      await ProfileImageService.clear();

      if (mounted) {
        await context.read<StepTracker>().loadForUser(uid);
        await context.read<ProfileImageProvider>().loadForUser(uid);
      }

      if (mounted) {
        setState(() {
          _providersLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading providers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const LoginPage();
    }

    if (!currentUser.emailVerified &&
        currentUser.providerData.any((p) => p.providerId == 'password')) {
      return const VerificationPage();
    }

    if (!_providersLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error loading user data.')),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const ProfileCompletionPage();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final bool onboardingComplete = data?['onboardingComplete'] ?? false;

        if (onboardingComplete) {
          return const Bottomnavigation(title: 'Steps4Perks');
        } else {
          return const OnboardingPage();
        }
      },
    );
  }
}
