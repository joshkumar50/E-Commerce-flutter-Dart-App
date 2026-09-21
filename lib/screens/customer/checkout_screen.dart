import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opem/core/router.dart';
import 'package:opem/core/theme.dart';
import 'package:opem/models/address.dart';
import 'package:opem/provider/cart_provider.dart';
import 'package:opem/services/address_service.dart';
import 'package:opem/services/analytics_service.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/services/checkout_service.dart';
import 'package:opem/services/remote_config_service.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _uuid = const Uuid();
  late final String _idempotencyKey;
  final TextEditingController _notesController = TextEditingController();

  Address? _selectedAddress;
  bool _isLoadingAddresses = true;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Unique idempotency key per checkout attempt to prevent double charges
    _idempotencyKey = _uuid.v4();
    _loadAddresses();
    // Non-blocking business funnel telemetry
    AnalyticsService.instance.trackCheckoutStarted(totalAmount: 0.0, itemCount: 0);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoadingAddresses = true);
    final user = authService.currentUser;
    final userId = user?.id ?? 'demo-user-123';
    try {
      final list = await addressService.fetchAddresses(userId);
      if (mounted) {
        setState(() {
          _selectedAddress = list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _handlePlaceOrder(CartProvider cart) async {
    // Check Emergency Server-Controlled Kill Switch
    if (RemoteConfigService.instance.isCheckoutDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout is temporarily paused by operations for maintenance. Please check back shortly.'),
          backgroundColor: AppColors.saleRed,
        ),
      );
      return;
    }

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a delivery address'),
          backgroundColor: AppColors.saleRed,
        ),
      );
      return;
    }

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // 1. Prepare items payload
      final cartPayload = cart.items.map((item) {
        return {
          'product_id': item.productId,
          'quantity': item.quantity,
        };
      }).toList();

      // 2. Authoritative Server-Side Checkout RPC
      final checkoutResult = await checkoutService.initiateCheckout(
        addressId: _selectedAddress!.id,
        cartItems: cartPayload,
        idempotencyKey: _idempotencyKey,
        notes: _notesController.text.trim(),
      );

      final orderId = checkoutResult['order_id'] as String;
      final orderNumber = checkoutResult['order_number'] as String;
      final grandTotal = (checkoutResult['grand_total'] as num).toDouble();
      final providerOrderId = checkoutResult['provider_order_id'] as String? ?? 'rzp_demo';

      if (!mounted) return;

      // 3. Launch Payment Simulation / Razorpay Sheet
      _showPaymentSheet(
        orderId: orderId,
        orderNumber: orderNumber,
        grandTotal: grandTotal,
        providerOrderId: providerOrderId,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showPaymentSheet({
    required String orderId,
    required String orderNumber,
    required double grandTotal,
    required String providerOrderId,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Business funnel telemetry
    AnalyticsService.instance.trackPaymentStarted(
      orderId: orderId,
      amount: grandTotal,
      method: 'upi',
    );

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF02042B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'RAZORPAY',
                              style: TextStyle(
                                color: Color(0xFF3395FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Payment Gateway',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      if (!isVerifying)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            // Safe recovery: release reserved stock upon user cancellation
                            await checkoutService.handlePaymentFailure(
                              orderId: orderId,
                              reason: 'Payment cancelled by user at gateway sheet',
                            );
                            if (mounted) {
                              setState(() => _isSubmitting = false);
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(content: Text('Payment cancelled. Reserved items released.')),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderNumber,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Authoritative Grand Total',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        Text(
                          '₹${grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Payment Method',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                    title: const Text('UPI (Google Pay / PhonePe / Paytm)'),
                    subtitle: const Text('Fastest instant bank transfer'),
                    tileColor: AppColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    trailing: const Icon(Icons.check_circle, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            setSheetState(() => isVerifying = true);
                            try {
                              // Simulate payment provider success callback & server signature verification
                              final fakePaymentId = 'pay_${_uuid.v4().replaceAll('-', '').substring(0, 14)}';
                              final fakeSignature = 'sig_${_uuid.v4().replaceAll('-', '').substring(0, 14)}';

                              await checkoutService.verifyPayment(
                                orderId: orderId,
                                providerPaymentId: fakePaymentId,
                                providerSignature: fakeSignature,
                                paymentMethod: 'upi',
                              );

                              if (!mounted) return;
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }

                              // Clear local cart provider
                              final itemCount = cartProvider.items.length;
                              cartProvider.clearCart();

                              // Business funnel telemetry: order completed
                              AnalyticsService.instance.trackOrderCreated(
                                orderId: orderId,
                                totalAmount: grandTotal,
                                itemCount: itemCount,
                              );

                              // Navigate to Payment Result Screen
                              router.go(
                                Routes.paymentResult,
                                extra: {
                                  'success': true,
                                  'order_id': orderId,
                                  'order_number': orderNumber,
                                  'grand_total': grandTotal,
                                  'payment_id': fakePaymentId,
                                },
                              );
                            } catch (e) {
                              setSheetState(() => isVerifying = false);
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Payment verification failed: $e'),
                                  backgroundColor: AppColors.saleRed,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isVerifying
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Verifying with Bank Server...'),
                            ],
                          )
                        : Text('Pay ₹${grandTotal.toStringAsFixed(2)}'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final double subtotal = cart.totalAmount;
    final double deliveryFee = subtotal >= 500.0 ? 0.0 : 40.0;
    final double tax = double.parse((subtotal * 0.05).toStringAsFixed(2));
    final double estimatedTotal = subtotal + deliveryFee + tax;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSubmitting ? null : () => context.pop(),
        ),
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('Your cart is empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go(Routes.home),
                    child: const Text('Return to Shop'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.saleRedLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.saleRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.saleRed),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.saleRed, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ─── 1. Delivery Address Card ───────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Delivery Address',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () async {
                              await context.push(Routes.addresses);
                              _loadAddresses();
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingAddresses)
                        const LinearProgressIndicator()
                      else if (_selectedAddress != null) ...[
                        Text(
                          _selectedAddress!.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedAddress!.addressLine1}${_selectedAddress!.addressLine2.isNotEmpty ? ', ${_selectedAddress!.addressLine2}' : ''}, ${_selectedAddress!.city}, ${_selectedAddress!.state} - ${_selectedAddress!.postalCode}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${_selectedAddress!.phone}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ] else ...[
                        const Text(
                          'No address selected. Please add an address to deliver.',
                          style: TextStyle(color: AppColors.saleRed, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await context.push(Routes.addresses);
                            _loadAddresses();
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Address'),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── 2. Order Items Snapshot ────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items (${cart.totalQuantity})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('Edit Cart'),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: AppColors.borderLight),
                      ...cart.items.map((item) {
                        final prod = item.product;
                        final name = prod?.name ?? 'Grocery Item';
                        final unit = prod?.unit ?? 'item';
                        final effectivePrice = prod?.effectivePrice ?? (prod?.salePrice ?? prod?.price ?? 0.0);
                        final imageUrl = prod?.imageUrl ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 44,
                                          height: 44,
                                          color: AppColors.surfaceMuted,
                                          child: const Icon(Icons.local_grocery_store, size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 44,
                                        height: 44,
                                        color: AppColors.surfaceMuted,
                                        child: const Icon(Icons.local_grocery_store, size: 20),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${item.quantity} x ₹${effectivePrice.toStringAsFixed(2)} • $unit',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${(effectivePrice * item.quantity).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── 3. Delivery Notes ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Instructions (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Leave package at front door, ring doorbell',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── 4. Price Breakdown ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Item Subtotal', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery Fee', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text(
                            deliveryFee == 0.0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: deliveryFee == 0.0 ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GST / Taxes (5%)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text('₹${tax.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '₹${estimatedTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── 5. Place Order Action (Double-Tap & Retry Protected) ────
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _handlePlaceOrder(cart),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Reserving Stock & Connecting...'),
                          ],
                        )
                      : Text(
                          'Place Order & Pay • ₹${estimatedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),

                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text(
                      'Server-authoritative 256-bit encrypted transaction',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
