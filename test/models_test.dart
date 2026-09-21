import 'package:flutter_test/flutter_test.dart';
import 'package:opem/models/address.dart';
import 'package:opem/models/cart_item.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/models/wishlist_item.dart';

void main() {
  group('Profile Model Tests', () {
    test('Profile parses from JSON correctly and identifies role', () {
      final json = {
        'id': 'usr-123',
        'full_name': 'Jane Doe',
        'email': 'jane@example.com',
        'avatar_url': 'https://example.com/avatar.jpg',
        'phone': '+1234567890',
        'role': 'admin',
        'created_at': '2026-09-21T10:00:00Z',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'usr-123');
      expect(profile.fullName, 'Jane Doe');
      expect(profile.email, 'jane@example.com');
      expect(profile.role, 'admin');
      expect(profile.isAdmin, isTrue);
      expect(profile.isCustomer, isFalse);
    });

    test('Profile defaults to customer role', () {
      final json = {
        'id': 'usr-456',
        'full_name': 'Bob Customer',
        'email': 'bob@example.com',
      };

      final profile = Profile.fromJson(json);

      expect(profile.role, 'customer');
      expect(profile.isCustomer, isTrue);
      expect(profile.isAdmin, isFalse);
    });
  });

  group('Category Model Tests', () {
    test('Category parses from JSON and serializes', () {
      final json = {
        'id': 'cat-fruits',
        'name': 'Fresh Fruits',
        'description': 'Organic fresh fruits',
        'image_url': 'https://example.com/fruits.jpg',
        'sort_order': 1,
        'is_active': true,
      };

      final category = Category.fromJson(json);

      expect(category.id, 'cat-fruits');
      expect(category.name, 'Fresh Fruits');
      expect(category.sortOrder, 1);
      expect(category.isActive, isTrue);

      final outJson = category.toJson();
      expect(outJson['name'], 'Fresh Fruits');
      expect(outJson['sort_order'], 1);
    });
  });

  group('Product Model Tests', () {
    test('Product handles pricing, discounts, and backward compatibility', () {
      final json = {
        'id': 10,
        'category_id': 'cat-dairy',
        'name': 'Farm Fresh Milk',
        'description': '1L Bottle',
        'price': 3.50,
        'sale_price': 2.99,
        'stock_quantity': 50,
        'unit': '1 Litre',
        'image_url': 'https://example.com/milk.jpg',
        'is_active': true,
      };

      final product = Product.fromJson(json);

      expect(product.id, 10);
      expect(product.name, 'Farm Fresh Milk');
      expect(product.title, 'Farm Fresh Milk'); // backward compatibility getter
      expect(product.imageUrl, 'https://example.com/milk.jpg');
      expect(product.image, 'https://example.com/milk.jpg'); // backward compatibility getter
      expect(product.price, 3.50);
      expect(product.salePrice, 2.99);
      expect(product.effectivePrice, 2.99);
      expect(product.hasDiscount, isTrue);
      expect(product.inStock, isTrue);
    });

    test('Product effectivePrice returns regular price when no sale_price exists', () {
      final json = {
        'id': 20,
        'name': 'Organic Eggs',
        'price': 4.00,
        'stock_quantity': 0,
      };

      final product = Product.fromJson(json);

      expect(product.effectivePrice, 4.00);
      expect(product.hasDiscount, isFalse);
      expect(product.inStock, isFalse);
    });
  });

  group('Address Model Tests', () {
    test('Address parses and formats full address string', () {
      final json = {
        'id': 'addr-001',
        'user_id': 'usr-123',
        'label': 'Home',
        'full_name': 'Jane Doe',
        'phone': '9876543210',
        'address_line1': '123 Main Street',
        'address_line2': 'Apt 4B',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'postal_code': '560001',
        'country': 'India',
        'is_default': true,
      };

      final address = Address.fromJson(json);

      expect(address.id, 'addr-001');
      expect(address.isDefault, isTrue);
      expect(
        address.formattedAddress,
        '123 Main Street, Apt 4B, Bengaluru, Karnataka - 560001, India',
      );
    });
  });

  group('Cart & Wishlist Model Tests', () {
    test('CartItem calculates subtotal accurately', () {
      const product = Product(
        id: 1,
        name: 'Whole Milk',
        price: 2.50,
        salePrice: 2.00,
        stockQuantity: 10,
      );

      final cartItem = CartItem(
        id: 'cart-1',
        userId: 'usr-123',
        productId: 1,
        quantity: 3,
        product: product,
      );

      expect(cartItem.subtotal, 6.00); // 3 * 2.00
    });

    test('WishlistItem parses from JSON with joined product', () {
      final json = {
        'id': 'wish-1',
        'user_id': 'usr-123',
        'product_id': 1,
        'products': {
          'id': 1,
          'name': 'Whole Milk',
          'price': 2.50,
        },
      };

      final item = WishlistItem.fromJson(json);

      expect(item.id, 'wish-1');
      expect(item.productId, 1);
      expect(item.product?.name, 'Whole Milk');
    });
  });
}
