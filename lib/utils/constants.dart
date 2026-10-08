library;

/// Global constants and environment configuration.
///
/// ⚠️  SECURITY NOTICE ⚠️
/// All sensitive credentials (Supabase URL, Anon Key, Google Client IDs) are
/// loaded EXCLUSIVELY via --dart-define or --dart-define-from-file at build
/// time. There are NO hardcoded fallback values in this file.
///
/// To run the app locally, create a .env.development file (see .env.example)
/// and pass it at run time:
///   flutter run --dart-define-from-file=.env.development
///
/// The .env files are listed in .gitignore and are NEVER committed.

const String appName = 'B-Buys Grocery';
const String adminAppName = 'B-Buys Store Admin';

/// Threshold below which products are flagged as 'Low Stock'
const int kLowStockThreshold = 10;

// ─── Supabase credentials ──────────────────────────────────────────────────
// Injected at build time via --dart-define or --dart-define-from-file.
// Never provide real credentials as defaultValue here.
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '', // Must be provided at build time
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '', // Must be provided at build time
);

const String authRedirectUri = String.fromEnvironment(
  'AUTH_REDIRECT_URI',
  defaultValue: 'io.supabase.bbuys://login-callback',
);

// ─── Google OAuth Client IDs ───────────────────────────────────────────────
const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID_WEB',
  defaultValue: '', // Must be provided at build time
);

const String googleIosClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID_IOS',
  defaultValue: '',
);

/// By default, demo mode is false (100% online through Supabase).
/// Can only be enabled explicitly during offline unit testing via --dart-define=DEMO_MODE=true.
const bool isDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);


// Normalized Database Table Names
const String tableProfiles      = 'profiles';
const String tableCategories    = 'categories';
const String tableProducts      = 'products';
const String tableProductImages = 'product_images';
const String tableAddresses     = 'addresses';
const String tableCartItems     = 'cart_items';
const String tableWishlists     = 'wishlists';
const String tableWishlistItems = 'wishlist_items';

// Phase 5 Transaction Engine Tables
const String tableOrdersV2               = 'orders';
const String tableOrderItems             = 'order_items';
const String tableInventoryReservations  = 'inventory_reservations';
const String tableInventoryLedger        = 'inventory_ledger';
const String tablePayments               = 'payments';
const String tableRefunds                = 'refunds';

// Phase 8 Operations & Analytics Tables
const String tableAnalyticsEvents        = 'analytics_events';
const String tableAdminAuditLogs         = 'admin_audit_logs';
const String tableAppConfig              = 'app_config';

// Phase 9 Advanced Platform Evolution Tables
const String tableEventOutbox            = 'event_outbox';
const String tableFulfillmentLocations   = 'fulfillment_locations';
const String tableInventoryByLocation    = 'inventory_by_location';

// Legacy Table Aliases for backward compatibility
const String tableProductsLegacy = 'Products';
const String tableOrdersLegacy   = 'Orders';
const String tableOrders         = 'Orders';

// Storage Buckets
const String bucketProductImages = 'product-images';
