import 'dart:async';
import 'package:opem/models/address.dart';
import 'package:opem/models/cart_item.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/models/wishlist_item.dart';

/// Static mock grocery data used in Demo Mode.
/// Images point to freely available Unsplash grocery photos.
class DemoDataService {
  static final StreamController<List<Product>> _productStreamController =
      StreamController<List<Product>>.broadcast();
  static final StreamController<List<Category>> _categoryStreamController =
      StreamController<List<Category>>.broadcast();
  // ─── Demo Profiles ─────────────────────────────────────────────────────────

  static const Profile demoCustomerProfile = Profile(
    id: 'demo-user-123',
    fullName: 'Alex Morgan',
    email: 'alex.morgan@example.com',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&q=80',
    phone: '+91 98765 43210',
    role: 'customer',
  );

  static const Profile demoAdminProfile = Profile(
    id: 'demo-admin-999',
    fullName: 'Store Admin',
    email: 'admin@bbuys.com',
    avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&q=80',
    phone: '+91 99999 88888',
    role: 'admin',
  );

  // ─── Demo Categories ───────────────────────────────────────────────────────

  static final List<Category> categories = [
    const Category(
      id: 'c1111111-1111-1111-1111-111111111111',
      name: 'Fruits',
      description: 'Fresh, juicy organic fruits harvested daily',
      imageUrl: 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?w=640&q=80',
      sortOrder: 1,
      isActive: true,
    ),
    const Category(
      id: 'c2222222-2222-2222-2222-222222222222',
      name: 'Vegetables',
      description: 'Farm-fresh green and root vegetables',
      imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=640&q=80',
      sortOrder: 2,
      isActive: true,
    ),
    const Category(
      id: 'c3333333-3333-3333-3333-333333333333',
      name: 'Dairy & Eggs',
      description: 'Pure milk, cheese, butter, and farm eggs',
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=640&q=80',
      sortOrder: 3,
      isActive: true,
    ),
    const Category(
      id: 'c4444444-4444-4444-4444-444444444444',
      name: 'Bakery',
      description: 'Artisan bread, buns, and fresh daily pastries',
      imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=640&q=80',
      sortOrder: 4,
      isActive: true,
    ),
    const Category(
      id: 'c5555555-5555-5555-5555-555555555555',
      name: 'Snacks',
      description: 'Nuts, dried fruits, chips, and chocolates',
      imageUrl: 'https://images.unsplash.com/photo-1621996346565-e3d5d6281729?w=640&q=80',
      sortOrder: 5,
      isActive: true,
    ),
    const Category(
      id: 'c6666666-6666-6666-6666-666666666666',
      name: 'Beverages',
      description: 'Cold pressed juices, mineral water, and tea',
      imageUrl: 'https://images.unsplash.com/photo-1534353473418-4cfa6c56fd38?w=640&q=80',
      sortOrder: 6,
      isActive: true,
    ),
  ];

  // ─── Demo Products ─────────────────────────────────────────────────────────

  static final List<Product> products = [
    const Product(
      id: 1,
      categoryId: 'c3333333-3333-3333-3333-333333333333',
      name: 'Organic Whole Milk',
      description: 'Fresh farm-sourced organic whole milk. Rich in calcium and vitamins. 1 litre bottle.',
      price: 2.49,
      salePrice: 2.19,
      stockQuantity: 150,
      unit: '1 Litre',
      imageUrl: 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 2,
      categoryId: 'c4444444-4444-4444-4444-444444444444',
      name: 'Fresh Sourdough Bread',
      description: 'Stone-baked sourdough with a crisp crust and chewy interior. Baked daily.',
      price: 4.99,
      stockQuantity: 45,
      unit: '500g loaf',
      imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 3,
      categoryId: 'c1111111-1111-1111-1111-111111111111',
      name: 'Ripe Hass Avocados (Pack of 3)',
      description: 'Hand-selected Hass avocados at peak ripeness. Perfect for guacamole or toast.',
      price: 3.99,
      salePrice: 3.49,
      stockQuantity: 80,
      unit: 'Pack of 3',
      imageUrl: 'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 4,
      categoryId: 'c3333333-3333-3333-3333-333333333333',
      name: 'Free-Range Eggs (12 pcs)',
      description: 'Dozen large free-range eggs from certified humane farms. Rich golden yolks.',
      price: 5.49,
      stockQuantity: 120,
      unit: '1 Dozen',
      imageUrl: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 5,
      categoryId: 'c3333333-3333-3333-3333-333333333333',
      name: 'Greek Yoghurt 500g',
      description: 'Thick and creamy full-fat Greek yoghurt. High protein, no artificial additives.',
      price: 3.29,
      stockQuantity: 60,
      unit: '500g Tub',
      imageUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 6,
      categoryId: 'c2222222-2222-2222-2222-222222222222',
      name: 'Organic Baby Spinach',
      description: 'Washed and ready-to-eat baby spinach. Perfect for salads and smoothies. 200g.',
      price: 2.79,
      salePrice: 2.29,
      stockQuantity: 95,
      unit: '200g Bag',
      imageUrl: 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 7,
      categoryId: 'c1111111-1111-1111-1111-111111111111',
      name: 'Golden Ripe Bananas',
      description: 'Sweet, naturally ripened Cavendish bananas. Rich in potassium and energy.',
      price: 1.89,
      stockQuantity: 200,
      unit: '1 kg',
      imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 8,
      categoryId: 'c1111111-1111-1111-1111-111111111111',
      name: 'Crisp Royal Gala Apples',
      description: 'Crisp, sweet, and juicy red Gala apples from highland orchards.',
      price: 3.49,
      salePrice: 2.99,
      stockQuantity: 140,
      unit: '1 kg pack',
      imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 9,
      categoryId: 'c2222222-2222-2222-2222-222222222222',
      name: 'Vine Ripe Red Tomatoes',
      description: 'Freshly picked red tomatoes with intense flavour for salads and curries.',
      price: 2.19,
      stockQuantity: 180,
      unit: '1 kg',
      imageUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 10,
      categoryId: 'c2222222-2222-2222-2222-222222222222',
      name: 'Red Onions (Farm Fresh)',
      description: 'Crisp and pungent red onions with tight skins. Kitchen essential.',
      price: 1.99,
      salePrice: 1.49,
      stockQuantity: 250,
      unit: '1 kg bag',
      imageUrl: 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 11,
      categoryId: 'c1111111-1111-1111-1111-111111111111',
      name: 'Fresh Green Kiwi (Pack of 4)',
      description: 'Tangy and vitamin C-packed Zespri green kiwis. Great for breakfast bowls.',
      price: 3.99,
      stockQuantity: 70,
      unit: 'Pack of 4',
      imageUrl: 'https://images.unsplash.com/photo-1585059895524-72359e06133a?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 12,
      categoryId: 'c1111111-1111-1111-1111-111111111111',
      name: 'Ruby Red Pomegranates',
      description: 'Sweet and antioxidant-rich whole ruby pomegranates.',
      price: 4.49,
      salePrice: 3.89,
      stockQuantity: 50,
      unit: '2 pcs',
      imageUrl: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 13,
      categoryId: 'c5555555-5555-5555-5555-555555555555',
      name: 'Rainforest Dark Chocolate (72%)',
      description: 'Single-origin Ecuadorian cacao bar with notes of roasted hazelnut and berry.',
      price: 3.49,
      stockQuantity: 110,
      unit: '100g Bar',
      imageUrl: 'https://images.unsplash.com/photo-1606312619070-d48b4c652a52?w=640&q=80',
      isActive: true,
    ),
    const Product(
      id: 14,
      categoryId: 'c6666666-6666-6666-6666-666666666666',
      name: 'Cold-Pressed Orange Juice',
      description: '100% pure squeezed Valencia oranges with juicy pulp. Never from concentrate.',
      price: 3.99,
      salePrice: 3.49,
      stockQuantity: 85,
      unit: '750ml Bottle',
      imageUrl: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=640&q=80',
      isActive: true,
    ),
  ];

  // ─── Demo Addresses ────────────────────────────────────────────────────────

  static final List<Address> addresses = [
    const Address(
      id: 'addr-1',
      userId: 'demo-user-123',
      label: 'Home',
      fullName: 'Alex Morgan',
      phone: '+91 98765 43210',
      addressLine1: 'Flat 402, Green Meadows Heights',
      addressLine2: 'Outer Ring Road',
      city: 'Bengaluru',
      state: 'Karnataka',
      postalCode: '560103',
      country: 'India',
      isDefault: true,
    ),
    const Address(
      id: 'addr-2',
      userId: 'demo-user-123',
      label: 'Work',
      fullName: 'Alex Morgan',
      phone: '+91 98765 43210',
      addressLine1: 'Tech Park Tower B, 5th Floor',
      addressLine2: 'Whitefield',
      city: 'Bengaluru',
      state: 'Karnataka',
      postalCode: '560066',
      country: 'India',
      isDefault: false,
    ),
  ];

  // ─── Demo Cart & Wishlist ──────────────────────────────────────────────────

  static final List<CartItem> cartItems = [
    CartItem(
      id: 'cart-1',
      userId: 'demo-user-123',
      productId: 1,
      quantity: 2,
      product: products[0],
    ),
    CartItem(
      id: 'cart-2',
      userId: 'demo-user-123',
      productId: 3,
      quantity: 1,
      product: products[2],
    ),
  ];

  static final Set<int> wishlistProductIds = {1, 3, 13};

  static List<WishlistItem> get wishlistItems {
    return wishlistProductIds
        .map((pid) => WishlistItem(
              id: 'wish-$pid',
              userId: 'demo-user-123',
              productId: pid,
              product: products.firstWhere((p) => p.id == pid),
            ))
        .toList();
  }

  // ─── Interactive Demo Helpers ──────────────────────────────────────────────

  static void addDemoCartItem(int productId, int quantity) {
    final existingIndex = cartItems.indexWhere((item) => item.productId == productId);
    if (existingIndex >= 0) {
      final existing = cartItems[existingIndex];
      cartItems[existingIndex] = existing.copyWith(quantity: existing.quantity + quantity);
    } else {
      final product = products.firstWhere((p) => p.id == productId, orElse: () => products.first);
      cartItems.add(CartItem(
        id: 'cart-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'demo-user-123',
        productId: productId,
        quantity: quantity,
        product: product,
      ));
    }
  }

  static void updateDemoCartQuantity(String cartItemId, int quantity) {
    final index = cartItems.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      if (quantity <= 0) {
        cartItems.removeAt(index);
      } else {
        cartItems[index] = cartItems[index].copyWith(quantity: quantity);
      }
    }
  }

  static void removeDemoCartItem(String cartItemId) {
    cartItems.removeWhere((item) => item.id == cartItemId);
  }

  static bool toggleDemoWishlist(int productId) {
    if (wishlistProductIds.contains(productId)) {
      wishlistProductIds.remove(productId);
      return false;
    } else {
      wishlistProductIds.add(productId);
      return true;
    }
  }

  /// Streams active products with realtime updates when admin edits data
  static Stream<List<Product>> watchActiveProducts() async* {
    yield products.where((p) => p.isActive).toList();
    yield* _productStreamController.stream.map((list) => list.where((p) => p.isActive).toList());
  }

  /// Streams all products (active and inactive) for admin management
  static Stream<List<Product>> watchAllAdminProducts() async* {
    yield List.unmodifiable(products);
    yield* _productStreamController.stream;
  }

  /// Streams active categories with realtime updates
  static Stream<List<Category>> watchActiveCategories() async* {
    yield categories.where((c) => c.isActive).toList();
    yield* _categoryStreamController.stream.map((list) => list.where((c) => c.isActive).toList());
  }

  /// Streams all categories for admin management
  static Stream<List<Category>> watchAllCategories() async* {
    yield List.unmodifiable(categories);
    yield* _categoryStreamController.stream;
  }

  // ─── Admin Product Mutations (Demo Mode) ───────────────────────────────────

  static void addDemoProduct(Product product) {
    final newId = products.isEmpty ? 1 : products.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
    final created = Product(
      id: newId,
      name: product.name,
      description: product.description,
      categoryId: product.categoryId,
      price: product.price,
      salePrice: product.salePrice,
      stockQuantity: product.stockQuantity,
      unit: product.unit,
      imageUrl: product.imageUrl.isNotEmpty
          ? product.imageUrl
          : 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=640&q=80',
      isActive: product.isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    products.insert(0, created);
    _productStreamController.add(List.unmodifiable(products));
  }

  static void updateDemoProduct(int id, Map<String, dynamic> updates, {int? expectedVersion}) {
    final index = products.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final current = products[index];
      if (expectedVersion != null && current.version != expectedVersion) {
        throw StaleVersionException(
          message: 'This product was modified by another administrator. Please refresh before saving.',
          currentVersion: current.version,
          expectedVersion: expectedVersion,
        );
      }
      products[index] = Product(
        id: current.id,
        name: updates.containsKey('name') ? updates['name'] as String : current.name,
        description: updates.containsKey('description') ? updates['description'] as String : current.description,
        categoryId: updates.containsKey('category_id') ? updates['category_id'] as String? : current.categoryId,
        price: updates.containsKey('price') ? (updates['price'] as num).toDouble() : current.price,
        salePrice: updates.containsKey('sale_price')
            ? (updates['sale_price'] != null ? (updates['sale_price'] as num).toDouble() : null)
            : current.salePrice,
        stockQuantity: updates.containsKey('stock_quantity')
            ? (updates['stock_quantity'] as num).toInt()
            : current.stockQuantity,
        unit: updates.containsKey('unit') ? updates['unit'] as String : current.unit,
        imageUrl: updates.containsKey('image_url') ? updates['image_url'] as String : current.imageUrl,
        isActive: updates.containsKey('is_active') ? updates['is_active'] as bool : current.isActive,
        version: current.version + 1,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      _productStreamController.add(List.unmodifiable(products));
    }
  }

  static void deleteDemoProduct(int id) {
    products.removeWhere((p) => p.id == id);
    _productStreamController.add(List.unmodifiable(products));
  }

  // ─── Admin Category Mutations (Demo Mode) ──────────────────────────────────

  static void addDemoCategory(Category category) {
    final id = 'cat-${DateTime.now().millisecondsSinceEpoch}';
    final created = category.copyWith(id: id);
    categories.add(created);
    _categoryStreamController.add(List.unmodifiable(categories));
  }

  static void updateDemoCategory(String id, Map<String, dynamic> updates) {
    final index = categories.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final current = categories[index];
      categories[index] = Category(
        id: current.id,
        name: updates.containsKey('name') ? updates['name'] as String : current.name,
        description: updates.containsKey('description') ? updates['description'] as String : current.description,
        imageUrl: updates.containsKey('image_url') ? updates['image_url'] as String : current.imageUrl,
        sortOrder: updates.containsKey('sort_order') ? (updates['sort_order'] as num).toInt() : current.sortOrder,
        isActive: updates.containsKey('is_active') ? updates['is_active'] as bool : current.isActive,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      _categoryStreamController.add(List.unmodifiable(categories));
    }
  }

  static void deleteDemoCategory(String id) {
    categories.removeWhere((c) => c.id == id);
    _categoryStreamController.add(List.unmodifiable(categories));
  }

  /// Returns a stream that immediately emits the mock product list for legacy widgets.
  static Stream<List<Map<String, dynamic>>> watchAllProducts() async* {
    yield products.map((p) => p.toInsertJson()..['id'] = p.id).toList();
  }
}
