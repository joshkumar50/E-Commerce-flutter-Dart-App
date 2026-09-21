import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../models/fulfillment_location.dart';
import '../../services/fulfillment_service.dart';

/// Fulfillment Locations / Dark Store Management Screen
class AdminLocationsScreen extends StatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  State<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends State<AdminLocationsScreen> {
  late Future<List<FulfillmentLocation>> _locationsFuture;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  void _loadLocations() {
    setState(() {
      _locationsFuture = FulfillmentService.instance.fetchLocations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fulfillment Locations & Dark Stores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Locations',
            onPressed: _loadLocations,
          ),
        ],
      ),
      body: FutureBuilder<List<FulfillmentLocation>>(
        future: _locationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminColors.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AdminColors.danger, size: 48),
                    const SizedBox(height: 12),
                    Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadLocations,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final locations = snapshot.data ?? [];
          if (locations.isEmpty) {
            return const Center(
              child: Text(
                'No fulfillment locations registered.',
                style: TextStyle(color: AdminColors.textMuted),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: locations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final loc = locations[index];
              return _buildLocationCard(loc);
            },
          );
        },
      ),
    );
  }

  Widget _buildLocationCard(FulfillmentLocation loc) {
    final typeColor = loc.type == 'dark_store'
        ? AdminColors.accent
        : (loc.type == 'central_warehouse' ? AdminColors.primary : AdminColors.warning);

    final typeLabel = loc.type == 'dark_store'
        ? 'Dark Store (Express)'
        : (loc.type == 'central_warehouse' ? 'Central Warehouse' : 'Retail Hub');

    final street = loc.address['street']?.toString() ?? '';
    final city = loc.address['city']?.toString() ?? '';
    final postal = loc.address['postal_code']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: typeColor, width: 1),
                  ),
                  child: Text(
                    typeLabel.toUpperCase(),
                    style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: loc.isActive
                        ? AdminColors.accent.withValues(alpha: 0.15)
                        : AdminColors.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    loc.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: loc.isActive ? AdminColors.accent : AdminColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              loc.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${loc.id}',
              style: const TextStyle(fontSize: 12, color: AdminColors.textMuted, fontFamily: 'monospace'),
            ),
            if (street.isNotEmpty || city.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AdminColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [street, city, postal].where((s) => s.isNotEmpty).join(', '),
                      style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_shipping_outlined, size: 16, color: AdminColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: loc.servicedPincodes.map((pin) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AdminColors.cardBorder),
                        ),
                        child: Text(
                          pin,
                          style: const TextStyle(fontSize: 11, color: AdminColors.textPrimary),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
