import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/barista/barista_screen.dart';
import '../features/customer_app/customer_home.dart';
import '../features/dashboard/admin_dashboard.dart';
import '../features/employees/employees_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/orders_history_screen.dart';
import '../features/pos/pos_screen.dart';
import '../features/products/categories_screen.dart';
import '../features/products/products_screen.dart';
import '../features/products/toppings_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tables/tables_screen.dart';
import '../features/vouchers/vouchers_screen.dart';
import 'role_router.dart';
import 'route_guard.dart';

class AppRouter {
  static GoRouter create(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (ctx, state) {
        final loggedIn = auth.isLoggedIn;
        final loc = state.matchedLocation;
        // Splash root: bao giờ cũng nhảy đi đâu đó
        if (loc == '/') {
          return loggedIn ? RoleRouter.homeFor(auth.role!) : '/login';
        }
        // Chưa login mà vào màn protected -> ép về login
        if (!loggedIn && loc != '/login') return '/login';
        // Đã login rồi mà còn vào /login -> đẩy về home theo role
        if (loggedIn && loc == '/login') {
          return RoleRouter.homeFor(auth.role!);
        }
        // Phân quyền theo role: vào màn không đúng quyền -> về home của role
        if (loggedIn && !RouteGuard.allowed(loc, auth.role!)) {
          return RoleRouter.homeFor(auth.role!);
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
        GoRoute(path: '/cashier', builder: (_, __) => const PosScreen()),
        GoRoute(path: '/barista', builder: (_, __) => const BaristaScreen()),
        GoRoute(path: '/waiter', builder: (_, __) => const TablesScreen()),
        GoRoute(path: '/customer', builder: (_, __) => const CustomerHome()),
        GoRoute(path: '/orders', builder: (_, __) => const OrdersHistoryScreen()),
        GoRoute(path: '/orders/:id', builder: (ctx, st) =>
            OrderDetailScreen(orderId: st.pathParameters['id']!)),
        GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
        GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
        GoRoute(path: '/toppings', builder: (_, __) => const ToppingsScreen()),
        GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
        GoRoute(path: '/recipes', builder: (_, __) => const RecipesScreen()),
        GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
        GoRoute(path: '/vouchers', builder: (_, __) => const VouchersScreen()),
        GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
        GoRoute(path: '/employees', builder: (_, __) => const EmployeesScreen()),
        GoRoute(path: '/tables', builder: (_, __) => const TablesScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
      errorBuilder: (_, st) => Scaffold(body: Center(child: Text('404: ' + st.matchedLocation))),
    );
  }
}
