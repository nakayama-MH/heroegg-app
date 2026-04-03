import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/hero_egg_scaffold.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/password_reset_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/events/presentation/event_list_screen.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../features/events/presentation/event_form_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/checkin/presentation/qr_scanner_screen.dart';
import '../../features/checkin/presentation/qr_scanner_web_screen.dart';
import '../../features/checkin/presentation/check_in_history_screen.dart';
import '../../features/home/presentation/facility_detail_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/home/presentation/facility_qr_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier();
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/password-reset' ||
          state.matchedLocation == '/auth/callback';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/password-reset',
        builder: (context, state) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/scan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            kIsWeb ? const QrScannerWebScreen() : const QrScannerScreen(),
      ),
      GoRoute(
        path: '/checkin-history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CheckInHistoryScreen(),
      ),
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/facility/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FacilityDetailScreen(facilityId: id);
        },
      ),
      GoRoute(
        path: '/qr/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? '';
          return FacilityQrScreen(facilityId: id, facilityName: name);
        },
      ),
      // イベント管理ルート
      GoRoute(
        path: '/events/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EventFormScreen(),
      ),
      GoRoute(
        path: '/events/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EventDetailScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/events/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EventFormScreen(eventId: id);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HeroEggScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                builder: (context, state) => const EventListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
