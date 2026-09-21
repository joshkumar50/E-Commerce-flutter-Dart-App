library;

/// Global constants and environment configuration.
/// Values can be supplied via `--dart-define` during build or left empty to use Demo Mode.

const String appName = 'B-Buys Grocery';
const String adminAppName = 'B-Buys Store Admin';

/// Threshold below which products are flagged as 'Low Stock'
const int kLowStockThreshold = 10;

// Supabase credentials (read from compilation environment or fallback to empty)
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

const String authRedirectUri = String.fromEnvironment(
  'AUTH_REDIRECT_URI',
  defaultValue: 'io.supabase.bbuys://login-callback',
);

const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID_WEB',
  defaultValue: '',
);

const String googleIosClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID_IOS',
  defaultValue: '',
);

/// True when Supabase credentials have not been configured.
/// The app uses DemoDataService with mock grocery data instead.
const bool isDemoMode = supabaseUrl == '';

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
