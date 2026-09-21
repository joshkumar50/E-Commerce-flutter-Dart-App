import 'package:flutter/material.dart';
import '../../services/remote_config_service.dart';

class AdminFeatureFlagsScreen extends StatefulWidget {
  const AdminFeatureFlagsScreen({super.key});

  @override
  State<AdminFeatureFlagsScreen> createState() => _AdminFeatureFlagsScreenState();
}

class _AdminFeatureFlagsScreenState extends State<AdminFeatureFlagsScreen> {
  bool _isLoading = false;
  late TextEditingController _maintenanceMsgController;

  @override
  void initState() {
    super.initState();
    _maintenanceMsgController = TextEditingController(
      text: RemoteConfigService.instance.maintenanceMessage,
    );
  }

  @override
  void dispose() {
    _maintenanceMsgController.dispose();
    super.dispose();
  }

  Future<void> _toggleFeature(String flag, bool val) async {
    setState(() => _isLoading = true);
    final success = await RemoteConfigService.instance.updateFeatureFlag(
      flag,
      val,
      reason: 'Toggled via Admin Feature Flags Screen',
    );
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Flag "$flag" set to ${val ? "ENABLED" : "DISABLED"}'
                : 'Failed to update flag "$flag"',
          ),
        ),
      );
    }
  }

  Future<void> _toggleKillSwitch(String switchName, bool active) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: active ? Colors.red : Colors.green),
            const SizedBox(width: 8),
            Text(active ? 'ENGAGE KILL SWITCH' : 'Disengage Kill Switch'),
          ],
        ),
        content: Text(
          active
              ? 'WARNING: Engaging "$switchName" will immediately halt this subsystem for all mobile users. Use only in disaster or third-party outage situations.\n\nAre you sure you want to proceed?'
              : 'Disengaging "$switchName" will restore normal operational flow for all mobile users.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: active ? Colors.red : Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(active ? 'Engage Emergency Switch' : 'Restore Subsystem'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final success = await RemoteConfigService.instance.setKillSwitch(
        switchName,
        active,
        reason: 'Emergency operator adjustment',
      );
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Kill Switch "$switchName" is now ${active ? "ACTIVE" : "INACTIVE"}'
                  : 'Failed to update kill switch "$switchName"',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleMaintenanceMode(bool enabled) async {
    setState(() => _isLoading = true);
    final success = await RemoteConfigService.instance.setMaintenanceMode(
      enabled,
      message: _maintenanceMsgController.text.trim(),
      reason: 'Admin toggled maintenance window',
    );
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Maintenance Mode set to ${enabled ? "ACTIVE" : "INACTIVE"}'
                : 'Failed to update maintenance mode',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = RemoteConfigService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags & Kill Switches'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Emergency Kill Switches Section
                _buildSectionHeader('Emergency Kill Switches (Operator Only)', Icons.power_settings_new, Colors.red),
                const SizedBox(height: 4),
                Text(
                  'Instantly halt critical paths during external provider outages without publishing a new app release.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _buildKillSwitchTile(
                  'Disable Checkout',
                  'Blocks customer order placement during inventory or database incidents.',
                  'disable_checkout',
                  config.isCheckoutDisabled,
                ),
                _buildKillSwitchTile(
                  'Disable Payments',
                  'Halts online payment processing during gateway provider outages.',
                  'disable_payments',
                  config.isPaymentsDisabled,
                ),
                _buildKillSwitchTile(
                  'Disable Refunds',
                  'Pauses automated refund processing during reconciliation reviews.',
                  'disable_refunds',
                  config.isRefundsDisabled,
                ),

                const SizedBox(height: 24),

                // Dynamic Feature Flags Section
                _buildSectionHeader('Dynamic Feature Flags', Icons.toggle_on, Colors.indigo),
                const SizedBox(height: 4),
                Text(
                  'Safely roll out or roll back capabilities dynamically.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _buildFeatureFlagTile(
                  'Personalized Recommendations',
                  'Shows recommended grocery items on Home and Product screens.',
                  'recommendations',
                  config.isFeatureEnabled('recommendations', defaultValue: true),
                ),
                _buildFeatureFlagTile(
                  'Enhanced Substring & Trigram Search',
                  'PostgreSQL trigram-accelerated fuzzy search with typo tolerance.',
                  'enhanced_search',
                  config.isFeatureEnabled('enhanced_search', defaultValue: true),
                ),
                _buildFeatureFlagTile(
                  'Promotional Deals Banner',
                  'Displays flash discounts carousel at top of customer Home screen.',
                  'deals_banner',
                  config.isFeatureEnabled('deals_banner', defaultValue: true),
                ),
                _buildFeatureFlagTile(
                  'Customer Review System',
                  'Enables rating and reviews on product detail pages.',
                  'review_system',
                  config.isFeatureEnabled('review_system', defaultValue: false),
                ),

                const SizedBox(height: 24),

                // Global Maintenance Mode Section
                _buildSectionHeader('Global Maintenance Mode', Icons.build_circle_outlined, Colors.orange),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Activate Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Blocks customer app with a friendly maintenance screen.'),
                          value: config.isMaintenanceMode,
                          activeThumbColor: Colors.orange,
                          onChanged: (val) => _toggleMaintenanceMode(val),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _maintenanceMsgController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Customer Notice Message',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Update Message'),
                            onPressed: () => _toggleMaintenanceMode(config.isMaintenanceMode),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildKillSwitchTile(String title, String subtitle, String switchName, bool isActive) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isActive ? Colors.red : Colors.grey.shade200, width: isActive ? 1.5 : 1),
      ),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.red : Colors.black87)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: isActive,
        activeThumbColor: Colors.red,
        onChanged: (val) => _toggleKillSwitch(switchName, val),
      ),
    );
  }

  Widget _buildFeatureFlagTile(String title, String subtitle, String flagName, bool isEnabled) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: isEnabled,
        activeThumbColor: Colors.green,
        onChanged: (val) => _toggleFeature(flagName, val),
      ),
    );
  }
}
