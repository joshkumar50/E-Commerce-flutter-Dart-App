library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Global constants and environment configuration.
/// Defaults to configured live Supabase cloud instance.

const String appName = 'B-Buys Grocery';
const String adminAppName = 'B-Buys Store Admin';

/// Threshold below which products are flagged as 'Low Stock'
const int kLowStockThreshold = 10;

// Supabase credentials (defaults to configured live cloud instance)
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://eqhkqkewhpvxfwaggkmt.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxaGtxa2V3aHB2eGZ3YWdna210Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwODAxMDMsImV4cCI6MjEwNTY1NjEwM30.Oqxw8a7YC4DacRPO4ZZPXI_rbtCwHkyNrHMdkephAmc',
);

const String authRedirectUri = String.fromEnvironment(
  'AUTH_REDIRECT_URI',
  defaultValue: 'io.supabase.bbuys://login-callback',
);

const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID_WEB',
  defaultValue: '698682998100-862m22e2v6f5jnbnja7rl1mejq9cokkr.apps.googleusercontent.com',
);

const String googleIosClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID_IOS',
  defaultValue: '',
);

/// True only during headless unit tests where Supabase has not been initialized.
/// In app runtime, Supabase is initialized at boot and isDemoMode is strictly false.
bool get isDemoMode {
  try {
    Supabase.instance;
    return false;
  } catch (_) {
    return true;
  }
}


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
