import 'package:flutter/material.dart';
import '../../services/data_health_service.dart';

class AdminHealthScreen extends StatefulWidget {
  const AdminHealthScreen({super.key});

  @override
  State<AdminHealthScreen> createState() => _AdminHealthScreenState();
}

class _AdminHealthScreenState extends State<AdminHealthScreen> {
  bool _isLoading = true;
  bool _isSweeping = false;
  Map<String, dynamic> _healthResult = {};
  List<AbuseRiskSignal> _abuseSignals = [];

  @override
  void initState() {
    super.initState();
    _refreshHealth();
  }

  Future<void> _refreshHealth() async {
    setState(() => _isLoading = true);
    final result = await DataHealthService.instance.runHealthCheck();

    // Evaluate abuse signals with sample orders and payments
    final signals = DataHealthService.instance.evaluateAbuseSignals(
      recentOrders: [
        {
          'id': 'ord-101',
          'user_id': 'u1',
          'status': 'confirmed',
          'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String()
        },
        {
          'id': 'ord-102',
          'user_id': 'u1',
          'status': 'confirmed',
          'created_at': DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String()
        },
      ],
      recentPayments: [
        {'id': 'pay-1', 'user_id': 'u2', 'status': 'failed'},
        {'id': 'pay-2', 'user_id': 'u2', 'status': 'failed'},
      ],
    );

    if (mounted) {
      setState(() {
        _healthResult = result;
        _abuseSignals = signals;
        _isLoading = false;
      });
    }
  }

  Future<void> _sweepReservations() async {
    setState(() => _isSweeping = true);
    final count = await DataHealthService.instance.sweepExpiredReservations();
    if (mounted) {
      setState(() => _isSweeping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reservation Sweeper: Released $count expired reservations.')),
      );
      _refreshHealth();
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'HEALTHY':
        return Colors.green;
      case 'DEGRADED':
        return Colors.orange;
      case 'ACTION_REQUIRED':
      case 'ERROR':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _healthResult['status']?.toString() ?? 'UNKNOWN';
    final color = _statusColor(status);
    final checks = _healthResult['checks'] as Map? ?? {};
    final actionCount = _healthResult['action_required_count'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Integrity & SRE Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshHealth,
            tooltip: 'Run Health Check',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshHealth,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Overall Status Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status == 'HEALTHY' ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: color,
                          size: 44,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SYSTEM STATUS: $status',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                actionCount == 0
                                    ? 'All transactional tables, stock records, and payments are healthy.'
                                    : '$actionCount items require operator attention.',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Operations Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isSweeping
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cleaning_services, size: 18),
                          label: const Text('Sweep Reservations'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isSweeping ? null : _sweepReservations,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Re-check Data'),
                          onPressed: _refreshHealth,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Integrity Checks Grid
                  const Text(
                    'Transactional Integrity Checks',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildCheckTile('Negative Stock Records', checks['negative_stock'] ?? 0, isCritical: true),
                  _buildCheckTile('Invalid Product Prices (<= 0)', checks['invalid_prices'] ?? 0, isCritical: true),
                  _buildCheckTile('Stuck Reservations (>15m)', checks['stuck_reservations'] ?? 0),
                  _buildCheckTile('Orphaned Order Items', checks['orphaned_order_items'] ?? 0, isCritical: true),
                  _buildCheckTile('Orphaned Payment Records', checks['orphaned_payments'] ?? 0, isCritical: true),
                  _buildCheckTile('Unresolved Payments (>2h)', checks['unresolved_payments'] ?? 0),
                  _buildCheckTile('Active Products Missing Category', checks['missing_categories'] ?? 0),
                  _buildCheckTile('Active Products Missing Image', checks['missing_images'] ?? 0),

                  const SizedBox(height: 24),

                  // Abuse & Fraud Detection Layer
                  const Text(
                    'Abuse & Anomaly Signals',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rules-based heuristics flag suspicious behavior for admin review. No accounts are automatically banned.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 12),

                  if (_abuseSignals.isEmpty)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user, color: Colors.green),
                            SizedBox(width: 12),
                            Text('No abnormal velocity or fraud patterns detected.'),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._abuseSignals.map((s) => _buildAbuseCard(s)),
                ],
              ),
            ),
    );
  }

  Widget _buildCheckTile(String title, int count, {bool isCritical = false}) {
    final hasIssue = count > 0;
    final color = hasIssue ? (isCritical ? Colors.red : Colors.orange) : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasIssue ? color.withValues(alpha: 0.5) : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(hasIssue ? Icons.warning_amber : Icons.check_circle_outline, color: color, size: 20),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbuseCard(AbuseRiskSignal signal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    signal.signal,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    signal.severity.toUpperCase(),
                    style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(signal.reason, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Colors.indigo),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recommendation: ${signal.actionRecommendation}',
                      style: const TextStyle(fontSize: 12, color: Colors.indigo),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
