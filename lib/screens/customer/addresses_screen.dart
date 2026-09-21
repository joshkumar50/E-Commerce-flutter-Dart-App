import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/core/theme.dart';
import 'package:opem/models/address.dart';
import 'package:opem/services/address_service.dart';
import 'package:opem/services/auth_service.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = authService.currentUserId ?? 'demo-user-123';
  }

  void _showAddAddressSheet([Address? existing]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final line1Ctrl = TextEditingController(text: existing?.addressLine1 ?? '');
    final line2Ctrl = TextEditingController(text: existing?.addressLine2 ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? 'Bengaluru');
    final stateCtrl = TextEditingController(text: existing?.state ?? 'Karnataka');
    final postalCtrl = TextEditingController(text: existing?.postalCode ?? '');
    String label = existing?.label ?? 'Home';
    bool isDefault = existing?.isDefault ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existing != null ? 'Edit Address' : 'Add New Address',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Contact Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter contact name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    validator: (v) => (v == null || v.trim().length < 8) ? 'Enter valid phone number' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: line1Ctrl,
                    decoration: const InputDecoration(labelText: 'Flat / House / Building / Street'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter address' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: line2Ctrl,
                    decoration: const InputDecoration(labelText: 'Area / Landmark (Optional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'City'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: postalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Postal Code'),
                          validator: (v) => (v == null || v.trim().length < 4) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setSheetState) {
                      return Row(
                        children: [
                          Checkbox(
                            value: isDefault,
                            onChanged: (v) => setSheetState(() => isDefault = v ?? false),
                          ),
                          const Text('Set as default delivery address'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final newAddr = Address(
                          id: existing?.id ?? 'addr-${DateTime.now().millisecondsSinceEpoch}',
                          userId: _userId,
                          label: label,
                          fullName: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          addressLine1: line1Ctrl.text.trim(),
                          addressLine2: line2Ctrl.text.trim(),
                          city: cityCtrl.text.trim(),
                          state: stateCtrl.text.trim(),
                          postalCode: postalCtrl.text.trim(),
                          isDefault: isDefault,
                        );

                        EasyLoading.show(status: 'Saving address…');
                        try {
                          if (existing != null) {
                            await addressService.updateAddress(newAddr);
                          } else {
                            await addressService.addAddress(newAddr);
                          }
                          EasyLoading.showSuccess('Address saved');
                          if (context.mounted) Navigator.pop(context);
                          setState(() {});
                        } catch (e) {
                          EasyLoading.showError('Failed to save address');
                        }
                      },
                      child: const Text('Save Address'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Delivery Addresses')),
      body: StreamBuilder<List<Address>>(
        stream: addressService.watchAddresses(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off_outlined, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No saved addresses',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Add your delivery address for fast grocery delivery.'),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddAddressSheet(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Address'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: addr.isDefault ? AppColors.primary : AppColors.border,
                    width: addr.isDefault ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              addr.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (addr.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'default') {
                              await addressService.setDefaultAddress(userId: _userId, addressId: addr.id);
                              setState(() {});
                            } else if (val == 'edit') {
                              _showAddAddressSheet(addr);
                            } else if (val == 'delete') {
                              await addressService.deleteAddress(addr.id);
                              setState(() {});
                            }
                          },
                          itemBuilder: (context) => [
                            if (!addr.isDefault)
                              const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.saleRed))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(addr.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(addr.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                      addr.formattedAddress,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer_addresses_fab',
        onPressed: () => _showAddAddressSheet(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
    );
  }
}
