import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'repositories/auth_repository.dart';
import 'providers/auth_provider.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';

import 'repositories/company_repository.dart';
import 'providers/company_provider.dart';
import 'repositories/company_tenant_repository.dart';
import 'providers/company_tenant_provider.dart';
import 'providers/feature_flags_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Inject AuthRepository
        Provider<AuthRepository>(
          create: (_) => AuthRepository(),
        ),
        // Inject AuthProvider which depends on AuthRepository
        ChangeNotifierProxyProvider<AuthRepository, AuthProvider>(
          create: (context) => AuthProvider(context.read<AuthRepository>()),
          update: (_, repository, previous) => previous ?? AuthProvider(repository),
        ),
        // Inject FeatureFlagsProvider
        ChangeNotifierProvider<FeatureFlagsProvider>(
          create: (_) => FeatureFlagsProvider(),
        ),
        // Inject CompanyRepository
        Provider<CompanyRepository>(
          create: (_) => CompanyRepository(),
        ),
        // Inject CompanyProvider which depends on CompanyRepository
        ChangeNotifierProxyProvider<CompanyRepository, CompanyProvider>(
          create: (context) => CompanyProvider(context.read<CompanyRepository>()),
          update: (_, repository, previous) => previous ?? CompanyProvider(repository),
        ),
        // Inject CompanyTenantRepository
        Provider<CompanyTenantRepository>(
          create: (_) => CompanyTenantRepository(),
        ),
        // Inject CompanyTenantProvider
        ChangeNotifierProxyProvider<CompanyTenantRepository, CompanyTenantProvider>(
          create: (context) => CompanyTenantProvider(context.read<CompanyTenantRepository>()),
          update: (_, repository, previous) => previous ?? CompanyTenantProvider(repository),
        ),
      ],
      child: MaterialApp(
        title: 'WorkTrack SuperAdmin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      ),
    );
  }
}
