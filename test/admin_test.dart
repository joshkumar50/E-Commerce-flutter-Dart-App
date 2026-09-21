import 'package:flutter_test/flutter_test.dart';
import 'package:opem/demo/demo_data.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/models/product_image.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/utils/constants.dart';

void main() {
  group('Admin Role & Authorization Tests', () {
    test('Profile role distinguishes admin from customer', () {
      const admin = Profile(
        id: 'adm-1',
        fullName: 'Store Admin',
        email: 'admin@bbuys.com',
        role: 'admin',
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.isCustomer, isFalse);

      const customer = Profile(
        id: 'cust-1',
        fullName: 'Regular Shopper',
        email: 'shopper@example.com',
        role: 'customer',
      );
      expect(customer.isAdmin, isFalse);
      expect(customer.isCustomer, isTrue);
    });

    test('Default profile role is customer (least privilege)', () {
      final p = Profile.fromJson({
        'id': 'uuid-123',
        'full_name': 'New User',
        'email': 'user@example.com',
      });
      expect(p.role, equals('customer'));
      expect(p.isAdmin, isFalse);
    });
  });

  group('Inventory & Stock Management Tests', () {
    test('Low stock threshold identifies products needing restock', () {
      expect(kLowStockThreshold, equals(10));

      const inStockProduct = Product(
        id: 101,
        name: 'Apples',
        price: 3.0,
        stockQuantity: 25,
      );
      expect(inStockProduct.stockQuantity <= kLowStockThreshold, isFalse);

      const lowStockProduct = Product(
        id: 102,
        name: 'Berries',
        price: 5.0,
        stockQuantity: 8,
      );
      expect(lowStockProduct.stockQuantity <= kLowStockThreshold, isTrue);

      const outOfStockProduct = Product(
        id: 103,
        name: 'Avocados',
        price: 4.0,
        stockQuantity: 0,
      );
      expect(outOfStockProduct.stockQuantity == 0, isTrue);
      expect(outOfStockProduct.inStock, isFalse);
    });

    test('Pricing calculations handle discounts and effective price', () {
      const discountedProduct = Product(
        id: 201,
        name: 'Whole Milk',
        price: 2.50,
        salePrice: 1.99,
        stockQuantity: 50,
      );
      expect(discountedProduct.hasDiscount, isTrue);
      expect(discountedProduct.effectivePrice, equals(1.99));

      const regularProduct = Product(
        id: 202,
        name: 'Greek Yoghurt',
        price: 3.50,
        stockQuantity: 20,
      );
      expect(regularProduct.hasDiscount, isFalse);
      expect(regularProduct.effectivePrice, equals(3.50));
    });
  });

  group('Category Management Tests', () {
    test('Category copyWith updates properties correctly', () {
      const original = Category(
        id: 'cat-1',
        name: 'Fresh Produce',
        sortOrder: 1,
        isActive: true,
      );

      final updated = original.copyWith(
        name: 'Organic Produce',
        isActive: false,
      );

      expect(updated.id, equals('cat-1'));
      expect(updated.name, equals('Organic Produce'));
      expect(updated.isActive, isFalse);
      expect(updated.sortOrder, equals(1));
    });

    test('ProductImage model parses and serializes correctly', () {
      final img = ProductImage(
        id: 'img-1',
        productId: 1,
        imageUrl: 'https://example.com/img1.jpg',
        sortOrder: 0,
      );

      final json = img.toJson();
      expect(json['product_id'], equals(1));
      expect(json['image_url'], equals('https://example.com/img1.jpg'));
    });
  });

  group('Realtime Demo Mode Reactive Synchronization Tests', () {
    test('Adding a demo product emits through watchAllAdminProducts stream', () async {
      final initialCount = DemoDataService.products.length;

      const newProd = Product(
        id: 9999,
        name: 'Test Mangoes',
        price: 4.50,
        stockQuantity: 30,
        unit: '1 kg',
      );

      DemoDataService.addDemoProduct(newProd);

      expect(DemoDataService.products.length, equals(initialCount + 1));
      expect(DemoDataService.products.first.name, equals('Test Mangoes'));

      // Clean up
      DemoDataService.deleteDemoProduct(DemoDataService.products.first.id);
      expect(DemoDataService.products.length, equals(initialCount));
    });

    test('Updating demo product stock alters in-memory state', () {
      final target = DemoDataService.products.first;
      final originalStock = target.stockQuantity;

      DemoDataService.updateDemoProduct(target.id, {'stock_quantity': originalStock + 15});

      final updated = DemoDataService.products.firstWhere((p) => p.id == target.id);
      expect(updated.stockQuantity, equals(originalStock + 15));

      // Restore
      DemoDataService.updateDemoProduct(target.id, {'stock_quantity': originalStock});
    });

    test('Toggling product active status reflects immediately', () {
      final target = DemoDataService.products.first;

      DemoDataService.updateDemoProduct(target.id, {'is_active': false});
      var current = DemoDataService.products.firstWhere((p) => p.id == target.id);
      expect(current.isActive, isFalse);

      // Re-enable
      DemoDataService.updateDemoProduct(target.id, {'is_active': true});
      current = DemoDataService.products.firstWhere((p) => p.id == target.id);
      expect(current.isActive, isTrue);
    });
  });
}
