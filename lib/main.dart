import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';

import 'firebase_options.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/features/profile_image_provider.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/services/profile_image_service.dart';
import 'package:myapp/view/onboardingpage.dart';
import 'package:myapp/view/auth/login_page.dart';
import 'package:myapp/view/auth/signup_page.dart';
import 'package:myapp/view/auth/verification_page.dart';
import 'package:myapp/view/auth/profile_completion_page.dart';
import 'package:myapp/features/bottomnavigation.dart';

final NotificationService notificationService = NotificationService();

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

  // Initialize Firebase
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized.');

  // Initialize Timezones
  try {
    tz.initializeTimeZones();
    debugPrint('✅ Timezones initialized.');
  } catch (e) {
    debugPrint('❌ Timezone init error: $e');
  }

  // Initialize Notification Service
  try {
    await notificationService.initialize();
    debugPrint('✅ NotificationService initialized.');
  } catch (e) {
    debugPrint('❌ NotificationService init error: $e');
  }

  runApp(const MyApp());
}

/// 🟢 Global key for accessing context without BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🟢 FIX: Move MultiProvider to the TOP of the tree
    // This ensures providers are available everywhere in the app
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

/// 🟢 AuthGate handles authentication state
/// Shows appropriate page based on user auth status
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        debugPrint(
            '🔄 AuthGate: Connection state = ${authSnapshot.connectionState}, has data = ${authSnapshot.hasData}');

        // Still connecting to Firebase
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is authenticated
        if (authSnapshot.hasData && authSnapshot.data != null) {
          final user = authSnapshot.data!;
          debugPrint('✅ AuthGate: User logged in = ${user.email}');

          // 🟢 REFACTORED: Pass user to the new router
          return UserPageRouter(user: user);
        }

        // User is not authenticated
        debugPrint('⚠️ AuthGate: No user, showing LoginPage');

        // 🟢 --- THIS IS THE FIX ---
        // Schedule the provider-clearing to run *after* the build is complete
        // to prevent the "setState/notifyListeners called during build" error.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _clearAllProvidersSync(context);
        });

        return const LoginPage();
      },
    );
  }

  /// 🟢 NEW: Synchronous clear that doesn't need postFrameCallback
  void _clearAllProvidersSync(BuildContext context) {
    try {
      // Use try-catch because providers might not exist yet
      final stepTracker = context.read<StepTracker>();
      final profileImageProvider = context.read<ProfileImageProvider>();

      stepTracker.clear();
      profileImageProvider.clear();
      ProfileImageService.clearAll();

      debugPrint('🧹 All providers cleared on logout');
    } catch (e) {
      debugPrint('⚠️ Could not clear providers (might not exist yet): $e');
    }
  }
}

//
// 🟢 --- START OF REFACTORED WIDGET ---
//

/// 🟢 REFACTORED: This widget handles all routing logic for an authenticated user.
/// It loads providers and then uses a StreamBuilder to determine which page to show.
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

    // Load providers after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProvidersForUser(widget.user.uid);
      }
    });

    // In UserPageRouter initState(), replace the auth listener with:
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (mounted && user != null && user.uid == widget.user.uid) {
            debugPrint(
                '🔄 Auth state updated for user ${user.uid}, emailVerified: ${user.emailVerified}');

            // 🟢 FIX: Simple reload without forceRefresh parameter
            user.reload().then((_) {
              // Get fresh user object after reload
              final freshUser = FirebaseAuth.instance.currentUser;
              if (freshUser != null) {
                debugPrint(
                    '✅ User reloaded: emailVerified = ${freshUser.emailVerified}');

                if (mounted) {
                  setState(() {
                    debugPrint('✅ UserPageRouter: Rebuilding with fresh user data');
                  });
                }
              }
            }).catchError((e) {
              debugPrint('❌ Error reloading user: $e');
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
    // 🟢 FIX: Cast oldWidget to UserPageRouter
    if (oldWidget.user.uid != widget.user.uid) {
      _loadProvidersForUser(widget.user.uid);
    }
  }

  Future<void> _loadProvidersForUser(String uid) async {
    if (!mounted) return;

    if (_loadedForUid == uid && _providersLoaded) {
      debugPrint('✅ Providers already loaded for $uid');
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

      debugPrint('✅ Providers loaded for user: $uid');

      if (mounted) {
        setState(() {
          _providersLoaded = true;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ Error loading providers: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 CRITICAL FIX: Get the latest user object from FirebaseAuth
    // This ensures we always have the most up-to-date emailVerified status
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      debugPrint('❌ User logged out unexpectedly');
      return const LoginPage();
    }

    // 🟢 FIX: Check email verification with FRESH user data
    // This is the key to fixing the stuck verification page issue
    if (!currentUser.emailVerified &&
        currentUser.providerData.any((p) => p.providerId == 'password')) {
      debugPrint(
          '🔐 User email not verified yet, showing VerificationPage. EmailVerified: ${currentUser.emailVerified}');
      return const VerificationPage();
    }

    // Email is verified, continue with normal flow
    if (!_providersLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Listen to Firestore for onboarding status
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
          debugPrint('❌ Error in UserPageRouter stream: ${snapshot.error}');
          return const Scaffold(
            body: Center(child: Text('Error loading user data.')),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          debugPrint('📝 User doc not found, showing ProfileCompletionPage');
          return const ProfileCompletionPage();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final bool onboardingComplete = data?['onboardingComplete'] ?? false;

        debugPrint(
            '📋 UserPageRouter: Onboarding complete = $onboardingComplete');

        if (onboardingComplete) {
          return const Bottomnavigation(title: 'Steps4Perks');
        } else {
          return const OnboardingPage();
        }
      },
    );
  }
}
