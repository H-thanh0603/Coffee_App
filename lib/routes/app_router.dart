import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/enums.dart';
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
import '../features/products/products_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/tables/tables_screen.dart';
import '../features/vouchers/vouchers_screen.dart';
import 'role_router.dart';

class AppRouter {
  static GoRouter create(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (ctx, state) {
        final loggedIn = auth.isLoggedIn;
        final goingAuth = state.matchedLocation == '/login' ||
            state.matchedLocation == '/';
        if (!loggedIn && !goingAuth) return '/login';
        if (loggedIn && goingAuth) return RoleRouter.homeFor(auth.role!);
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
        GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
        GoRoute(path: '/recipes', builder: (_, __) => const RecipesScreen()),
        GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
        GoRoute(path: '/vouchers', builder: (_, __) => const VouchersScreen()),
        GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
        GoRoute(path: '/employees', builder: (_, __) => const EmployeesScreen()),
        GoRoute(path: '/tables', builder: (_, __) => const TablesScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
      errorBuilder: (_, st) => Scaffold(body: Center(child: Text('404: ' + st.matchedLocation))),
    );
  }
}
