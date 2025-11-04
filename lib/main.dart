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
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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

// 🟢 Global key for accessing context without BuildContext
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
    return StreamBuilder<User?>(
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
          return UserPageRouter(user: user);
        }

        // User is not authenticated
        debugPrint('⚠️ AuthGate: No user, showing LoginPage');

        // 🟢 FIX: Clear providers when user logs out
        _clearAllProvidersSync(context);

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

/// 🟢 FIXED: This widget listens to user doc and handles onboarding navigation
/// It now properly detects when onboarding is complete and navigates to home
class UserPageRouter extends StatefulWidget {
  final User user;

  const UserPageRouter({super.key, required this.user});

  @override
  State<UserPageRouter> createState() => _UserPageRouterState();
}

class _UserPageRouterState extends State<UserPageRouter> {
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  Widget _currentPage = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
  bool _hasLoadedProviders = false;
  bool _hasNavigatedToHome = false; // 🟢 NEW: Track if we already navigated
  String? _lastLoadedUid; // 🟢 Track which user's data we loaded

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 UserPageRouter: initState for user ${widget.user.email}');
    _lastLoadedUid = widget.user.uid;
    _listenToUserDocument();
  }

  @override
  void didUpdateWidget(UserPageRouter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 🟢 If user changed, reset everything
    if (oldWidget.user.uid != widget.user.uid) {
      debugPrint(
          '🔄 UserPageRouter: User changed from ${oldWidget.user.email} to ${widget.user.email}');
      _hasLoadedProviders = false;
      _hasNavigatedToHome = false; // 🟢 NEW: Reset navigation flag
      _lastLoadedUid = widget.user.uid;
      _userDocSubscription?.cancel();
      _listenToUserDocument();
    }
  }

  void _listenToUserDocument() {
    // Check verification first (for email/password users)
    if (!widget.user.emailVerified &&
        widget.user.providerData.any((p) => p.providerId == 'password')) {
      setState(() {
        _currentPage = const VerificationPage();
      });
      return;
    }

    // User is verified, listen to their document
    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots()
        .listen((userDocSnapshot) async {
      // 🟢 Ignore old user's data
      if (_lastLoadedUid != widget.user.uid) return;

      if (!userDocSnapshot.exists) {
        // User document doesn't exist yet - show profile completion
        if (mounted) {
          setState(() {
            _currentPage = const ProfileCompletionPage();
          });
        }
      } else {
        // User document exists - check onboarding status
        final data = userDocSnapshot.data() as Map<String, dynamic>?;
        final bool onboardingComplete =
        data?.containsKey('onboardingComplete') == true
            ? data!['onboardingComplete']
            : false;

        debugPrint('📋 Onboarding status: $onboardingComplete');

        if (onboardingComplete) {
          // 🟢 FIXED: Load providers ONLY ONCE and navigate
          if (!_hasLoadedProviders &&
              mounted &&
              _lastLoadedUid == widget.user.uid) {
            debugPrint('🔄 Loading providers for user: ${widget.user.uid}');
            await _loadProvidersForUser(widget.user.uid);
            _hasLoadedProviders = true;
          }

          // 🟢 NEW: Check if we already navigated, to avoid duplicate navigations
          if (!_hasNavigatedToHome &&
              mounted &&
              _lastLoadedUid == widget.user.uid) {
            debugPrint('✅ Setting currentPage to Bottomnavigation (Home)');
            _hasNavigatedToHome = true;
            setState(() {
              _currentPage =
              const Bottomnavigation(title: 'Steps4Perks');
            });
          }
        } else {
          // Onboarding not complete - show onboarding page
          debugPrint('⏳ Onboarding not complete, showing OnboardingPage');
          if (mounted && _lastLoadedUid == widget.user.uid) {
            _hasNavigatedToHome = false; // Reset in case they restart onboarding
            setState(() {
              _currentPage = const OnboardingPage();
            });
          }
        }
      }
    }, onError: (error) {
      debugPrint('❌ Error listening to user document: $error');
      if (mounted && _lastLoadedUid == widget.user.uid) {
        setState(() {
          _currentPage = const Scaffold(
            body: Center(child: Text('Error loading user data.')),
          );
        });
      }
    });
  }

  Future<void> _loadProvidersForUser(String uid) async {
    if (!mounted) return;

    try {
      debugPrint('🔄 Loading providers for user: $uid');

      // Clear old state first
      if (mounted) {
        context.read<StepTracker>().clear();
        context.read<ProfileImageProvider>().clear();
      }
      await ProfileImageService.clear();

      // Load new user data
      if (mounted) {
        await context.read<StepTracker>().loadForUser(uid);
        await context.read<ProfileImageProvider>().loadForUser(uid);
      }

      debugPrint('✅ Providers loaded for user: $uid');
    } catch (e, stack) {
      debugPrint('❌ Error loading providers: $e\n$stack');
    }
  }

  @override
  void dispose() {
    debugPrint('🔴 UserPageRouter: dispose');
    _userDocSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _currentPage;
  }
}
