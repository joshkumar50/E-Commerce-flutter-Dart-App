import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/data_health_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _funnelData = {};
  Map<String, dynamic> _dashboardMetrics = {};
  String _selectedPeriod = '30 Days';

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final days = _selectedPeriod == '7 Days' ? 7 : (_selectedPeriod == '30 Days' ? 30 : 90);
    final startDate = DateTime.now().subtract(Duration(days: days));

    final results = await Future.wait([
      AnalyticsService.instance.fetchBusinessFunnel(startDate: startDate),
      DataHealthService.instance.fetchAdminDashboardMetrics(),
    ]);

    if (mounted) {
      setState(() {
        _funnelData = results[0];
        _dashboardMetrics = results[1];
        _isLoading = false;
      });
    }
  }

  Future<void> _purgeOldTelemetry() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purge Expired Telemetry'),
        content: const Text(
          'This will purge analytics events older than 90 days in bounded batches to conserve storage.\n\nAuthoritative financial records will NOT be affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Purge (90+ Days)'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleted = await AnalyticsService.instance.purgeExpiredTelemetry(daysRetention: 90);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully purged $deleted expired telemetry events.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Intelligence & Funnel'),
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            dropdownColor: Colors.white,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: '7 Days', child: Text('7 Days')),
              DropdownMenuItem(value: '30 Days', child: Text('30 Days')),
              DropdownMenuItem(value: '90 Days', child: Text('90 Days')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedPeriod = val);
                _loadMetrics();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // KPI Overview Cards
                  _buildKpiOverview(),
                  const SizedBox(height: 20),

                  // Business Funnel Section
                  _buildFunnelCard(),
                  const SizedBox(height: 20),

                  // Payment & Fulfillment Health
                  _buildPaymentHealthCard(),
                  const SizedBox(height: 20),

                  // Storage & Retention Management
                  _buildRetentionCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiOverview() {
    final customers = _dashboardMetrics['customers'] as Map? ?? {};
    final catalog = _dashboardMetrics['catalog'] as Map? ?? {};
    final orders = _dashboardMetrics['orders'] as Map? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operational Performance Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Revenue',
                value: '₹${orders['total_revenue'] ?? '0.00'}',
                icon: Icons.currency_rupee,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Total Orders',
                value: '${orders['total'] ?? 0}',
                subtitle: '${orders['delivered'] ?? 0} delivered',
                icon: Icons.shopping_bag,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Customers',
                value: '${customers['total'] ?? 0}',
                subtitle: '+${customers['new_30d'] ?? 0} new (30d)',
                icon: Icons.people,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Catalog Health',
                value: '${catalog['active'] ?? 0} Active',
                subtitle: '${catalog['low_stock'] ?? 0} low stock',
                icon: Icons.inventory_2,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFunnelCard() {
    final stages = _funnelData['stages'] as Map? ?? {};
    final dropoffs = _funnelData['dropoffs'] as Map? ?? {};
    final conversion = _funnelData['overall_conversion_percent'] ?? '0.0';

    final appOpens = stages['app_opened'] ?? 0;
    final views = stages['product_viewed'] ?? 0;
    final cartAdds = stages['cart_item_added'] ?? 0;
    final checkouts = stages['checkout_started'] ?? 0;
    final payments = stages['payment_started'] ?? 0;
    final orders = stages['order_completed'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Conversion Funnel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  'Conversion: $conversion%',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFunnelStage('1. App Opened', appOpens, appOpens > 0 ? 1.0 : 0.0, Colors.blue),
          _buildFunnelDropoff('Drop-off', '${dropoffs['view_to_cart_pct'] ?? 0}%'),
          _buildFunnelStage('2. Product Viewed', views, appOpens > 0 ? (views / appOpens).clamp(0.0, 1.0) : 0.0, Colors.indigo),
          _buildFunnelDropoff('Cart Abandonment', '${dropoffs['cart_to_checkout_pct'] ?? 0}%'),
          _buildFunnelStage('3. Added to Cart', cartAdds, appOpens > 0 ? (cartAdds / appOpens).clamp(0.0, 1.0) : 0.0, Colors.teal),
          _buildFunnelDropoff('Checkout Drop-off', '${dropoffs['checkout_to_payment_pct'] ?? 0}%'),
          _buildFunnelStage('4. Checkout Started', checkouts, appOpens > 0 ? (checkouts / appOpens).clamp(0.0, 1.0) : 0.0, Colors.orange),
          _buildFunnelDropoff('Payment Abandonment', '${dropoffs['payment_to_order_pct'] ?? 0}%'),
          _buildFunnelStage('5. Payment Started', payments, appOpens > 0 ? (payments / appOpens).clamp(0.0, 1.0) : 0.0, Colors.amber.shade700),
          _buildFunnelStage('6. Order Completed', orders, appOpens > 0 ? (orders / appOpens).clamp(0.0, 1.0) : 0.0, Colors.green),
        ],
      ),
    ),
  );
  }

  Widget _buildFunnelStage(String label, dynamic count, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('$count events', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.05, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelDropoff(String label, String rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.arrow_downward, size: 14, color: Colors.red.shade400),
          const SizedBox(width: 4),
          Text(
            '$label: $rate',
            style: TextStyle(color: Colors.red.shade600, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHealthCard() {
    final payments = _dashboardMetrics['payments'] as Map? ?? {};
    final success = payments['successful'] ?? 0;
    final failed = payments['failed'] ?? 0;
    final refunded = payments['refunded'] ?? 0;
    final failureRate = payments['failure_rate_pct'] ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment Processing Health',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Failure Rate: $failureRate%',
                  style: TextStyle(
                    color: (failureRate > 10.0) ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPaymentStatusIndicator('Captured', success, Colors.green),
                _buildPaymentStatusIndicator('Failed', failed, Colors.red),
                _buildPaymentStatusIndicator('Refunded', refunded, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusIndicator(String label, dynamic count, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildRetentionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_delete_outlined, color: Colors.blueGrey.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Telemetry Retention & Archival',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Policy: Financial orders and payments are permanently preserved. Bounded background cleanup safely deletes analytics events older than 90 days.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Purge Old Telemetry (>90d)'),
                onPressed: _purgeOldTelemetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
