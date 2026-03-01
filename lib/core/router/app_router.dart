import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/planning/presentation/pages/planning_page.dart';
import '../../features/ai_chat/presentation/pages/ai_chat_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/products/presentation/pages/product_detail_page.dart';
import '../../features/tools/presentation/pages/tools_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/login_page.dart';
import '../../features/profile/presentation/pages/register_page.dart';
import '../../features/fund_tracker/presentation/pages/fund_tracker_page.dart';
import '../../features/fund_tracker/presentation/pages/add_fund_page.dart';
import '../../features/fund_tracker/presentation/pages/alert_settings_page.dart';
import '../../shared/widgets/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ── Shell：带底部导航栏的 4 个主 Tab ──
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'planning',
            builder: (context, state) => const PlanningPage(),
          ),
          GoRoute(
            path: '/products',
            name: 'products',
            builder: (context, state) => const ProductsPage(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'product-detail',
                builder: (context, state) => ProductDetailPage(
                  productId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/tools',
            name: 'tools',
            builder: (context, state) => const ToolsPage(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),

      // ── 全屏页面（不带底部导航栏）──
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => const AiChatPage(),
      ),
      GoRoute(
        path: '/fund-tracker',
        name: 'fund-tracker',
        builder: (context, state) => const FundTrackerPage(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'fund-tracker-add',
            builder: (context, state) => const AddFundPage(),
          ),
          GoRoute(
            path: 'alert-settings',
            name: 'fund-tracker-alert-settings',
            builder: (context, state) => const AlertSettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面未找到: ${state.error}'),
      ),
    ),
  );
});
