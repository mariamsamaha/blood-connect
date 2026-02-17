import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:bloodconnect/routing/app_router.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/services/database_service.dart';
import 'package:bloodconnect/services/auth_service.dart';
import 'package:bloodconnect/services/request_service.dart';
import 'package:bloodconnect/services/location_service.dart';
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final host = Platform.isIOS ? '127.0.0.1' : '127.0.0.1';
  
  return DatabaseService(
    host: host,
    port: 5432,
    database: 'bloodconnect_dev',
    username: 'bloodconnect_user',
    password: 'bloodconnect123',
  );
});

final userServiceProvider = Provider<UserService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return UserService(db);
});
final requestServiceProvider = Provider<RequestService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return RequestService(db);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userService = ref.watch(userServiceProvider);
  return buildRouter(authService: authService, userService: userService);
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: BloodConnectApp()));
}

class BloodConnectApp extends ConsumerWidget {
  const BloodConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'BloodConnect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}