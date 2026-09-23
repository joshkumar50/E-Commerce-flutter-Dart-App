import 'package:go_router/go_router.dart';
import 'package:opem/models/product.dart';
import 'package:opem/screens/b_orders_screen.dart';
import 'package:opem/screens/change_password.dart';
import 'package:opem/screens/customer/addresses_screen.dart';
import 'package:opem/screens/customer/cart_screen.dart';
import 'package:opem/screens/customer/main_navigation_screen.dart';
import 'package:opem/screens/customer/product_detail_screen.dart';
import 'package:opem/screens/customer/search_screen.dart';
import 'package:opem/screens/customer/wishlist_screen.dart';
import 'package:opem/screens/login_screen.dart';
import 'package:opem/screens/my_products_screen.dart';
import 'package:opem/screens/register_screen.dart';
import 'package:opem/screens/s_orders_screen.dart';
import 'package:opem/screens/sell_screen.dart';
import 'package:opem/models/order_v2.dart';
import 'package:opem/screens/customer/checkout_screen.dart';
import 'package:opem/screens/customer/order_detail_screen.dart';
import 'package:opem/screens/customer/order_history_screen.dart';
import 'package:opem/screens/customer/payment_result_screen.dart';
import 'package:opem/screens/phone_login_screen.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/utils/constants.dart';

/// Named route constants for customer app and auth.
class Routes {
  static const login          = '/login';
  static const register       = '/register';
  static const phoneLogin     = '/phone-login';
  static const home           = '/';
  static const productDetail  = '/product';
  static const search         = '/search';
  static const cart           = '/cart';
  static const wishlist       = '/wishlist';
  static const addresses      = '/addresses';
  static const forgotPassword = '/forgot-password';
  static const checkout       = '/checkout';
  static const paymentResult  = '/payment-result';
  static const orders         = '/orders';

  // Legacy routes preserved for backward compatibility
  static const sell           = '/sell';
  static const myProducts     = '/my-products';
  static const buyOrders      = '/buy-orders';
  static const sellOrders     = '/sell-orders';
}

final appRouter = GoRouter(
  initialLocation: authService.isSignedIn ? Routes.home : Routes.login,
  redirect: (context, state) {
    if (isDemoMode) return null;

    final signedIn = authService.isSignedIn;
    final loc = state.matchedLocation;
    final isAuthScreen = loc == Routes.login ||
        loc == Routes.register ||
        loc == Routes.phoneLogin ||
        loc == Routes.forgotPassword;

    if (!signedIn && !isAuthScreen) return Routes.login;
    if (signedIn && (loc == Routes.login || loc == Routes.register || loc == Routes.phoneLogin)) {
      return Routes.home;
    }
    return null;
  },
  routes: [
    GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
    GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
    GoRoute(path: Routes.phoneLogin, builder: (_, __) => const PhoneLoginScreen()),
    GoRoute(path: Routes.forgotPassword, builder: (_, __) => ForgotPasswordScreen()),

    // Customer App Main Navigation (Persistent Bottom Navigation)
    GoRoute(
      path: Routes.home,
      builder: (_, state) {
        final tabParam = state.uri.queryParameters['tab'];
        final initialIndex = tabParam != null ? int.tryParse(tabParam) ?? 0 : 0;
        return MainNavigationScreen(initialIndex: initialIndex);
      },
    ),

    // Product Detail
    GoRoute(
      path: Routes.productDetail,
      builder: (_, state) => ProductDetailScreen(product: state.extra as Product),
    ),

    // Search
    GoRoute(path: Routes.search, builder: (_, __) => const SearchScreen()),

    // Cart (direct route or via bottom nav tab 3)
    GoRoute(path: Routes.cart, builder: (_, __) => const CartScreen()),

    // Wishlist (direct route or via bottom nav tab 2)
    GoRoute(path: Routes.wishlist, builder: (_, __) => const WishlistScreen()),

    // Addresses
    GoRoute(path: Routes.addresses, builder: (_, __) => const AddressesScreen()),

    // Checkout & Payment
    GoRoute(path: Routes.checkout, builder: (_, __) => const CheckoutScreen()),
    GoRoute(
      path: Routes.paymentResult,
      builder: (_, state) => PaymentResultScreen(
        result: (state.extra as Map<String, dynamic>?) ?? const {},
      ),
    ),

    // Orders
    GoRoute(path: Routes.orders, builder: (_, __) => const OrderHistoryScreen()),
    GoRoute(
      path: '${Routes.orders}/:id',
      builder: (_, state) => OrderDetailScreen(
        orderId: state.pathParameters['id']!,
        initialOrder: state.extra as OrderV2?,
      ),
    ),

    // Legacy Routes
    GoRoute(path: Routes.sell, builder: (_, __) => const SellScreen()),
    GoRoute(path: Routes.myProducts, builder: (_, __) => const MyProductsScreen()),
    GoRoute(path: Routes.buyOrders, builder: (_, __) => const BOrders()),
    GoRoute(path: Routes.sellOrders, builder: (_, __) => const SOrders()),
  ],
);
