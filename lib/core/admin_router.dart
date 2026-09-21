import 'package:go_router/go_router.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/screens/admin/admin_auth_gate.dart';
import 'package:opem/screens/admin/admin_category_form_screen.dart';
import 'package:opem/screens/admin/admin_login_screen.dart';
import 'package:opem/screens/admin/admin_orders_screen.dart';
import 'package:opem/screens/admin/admin_product_form_screen.dart';

class AdminRoutes {
  static const home = '/';
  static const login = '/login';
  static const productNew = '/product/new';
  static const productEdit = '/product/edit';
  static const categoryNew = '/category/new';
  static const categoryEdit = '/category/edit';
  static const orders = '/orders';
}

final adminRouter = GoRouter(
  initialLocation: AdminRoutes.home,
  routes: [
    GoRoute(
      path: AdminRoutes.home,
      builder: (_, __) => const AdminAuthGate(),
    ),
    GoRoute(
      path: AdminRoutes.login,
      builder: (_, __) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: AdminRoutes.productNew,
      builder: (_, __) => const AdminProductFormScreen(),
    ),
    GoRoute(
      path: AdminRoutes.productEdit,
      builder: (_, state) => AdminProductFormScreen(
        product: state.extra as Product?,
      ),
    ),
    GoRoute(
      path: AdminRoutes.categoryNew,
      builder: (_, __) => const AdminCategoryFormScreen(),
    ),
    GoRoute(
      path: AdminRoutes.categoryEdit,
      builder: (_, state) => AdminCategoryFormScreen(
        category: state.extra as Category?,
      ),
    ),
    GoRoute(
      path: AdminRoutes.orders,
      builder: (_, __) => const AdminOrdersScreen(),
    ),
  ],
);
