import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'shared/theme/theme.dart';
import 'shared/routes/router.dart';
import 'shared/providers/providers.dart';
import 'shared/services/push_notification_service.dart';
import 'shared/services/migration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final container = ProviderContainer();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Trigger migration asynchronously
    MigrationService.runMigrations().catchError((e) {
      debugPrint('Migration startup error: $e');
    });

    // Enable Firestore offline persistence safely
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings initialization failed: $e');
    }

    // Initialize Firebase App Check only if a real site key is provided
    const appCheckSiteKey = String.fromEnvironment('APP_CHECK_SITE_KEY', defaultValue: '');
    if (appCheckSiteKey.isNotEmpty) {
      FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(appCheckSiteKey),
        providerAndroid: AndroidPlayIntegrityProvider(),
        providerApple: AppleAppAttestProvider(),
      ).then((_) {
        debugPrint('Firebase App Check activated successfully');
      }).catchError((e) {
        debugPrint('Firebase App Check activation failed: $e');
      });
    } else {
      debugPrint('Firebase App Check skipped: No valid site key provided.');
    }

    if (!kIsWeb) {
      // Initialize Firebase Crashlytics to report application crash logs
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // Initialize Push Notifications (FCM) asynchronously
    PushNotificationService().initialize().catchError((e) {
      debugPrint('Push Notification Service initialization failed: $e');
    });
  } catch (e) {
    debugPrint('Firebase initialization failed: $e. Running in offline/mock mode.');
    container.read(firebaseInitErrorProvider.notifier).state = e.toString();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WorkTrackApp(),
    ),
  );
}

class WorkTrackApp extends ConsumerWidget {
  const WorkTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'WorkTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
