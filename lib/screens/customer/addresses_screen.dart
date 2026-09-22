import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/models/address.dart';
import 'package:opem/services/address_service.dart';
import 'package:opem/services/auth_service.dart';
import 'package:opem/widgets/ui/empty_state_view.dart';
import 'package:opem/widgets/ui/pressable_scale.dart';

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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Contact Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter contact name' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    validator: (v) => (v == null || v.trim().length < 8) ? 'Enter valid phone number' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: line1Ctrl,
                    decoration: const InputDecoration(labelText: 'Flat / House / Building / Street'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter address' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: line2Ctrl,
                    decoration: const InputDecoration(labelText: 'Area / Landmark (Optional)'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'City'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
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
                  const SizedBox(height: AppSpacing.md),
                  StatefulBuilder(
                    builder: (context, setSheetState) {
                      return Row(
                        children: [
                          Checkbox(
                            value: isDefault,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setSheetState(() => isDefault = v ?? false),
                          ),
                          const Text(
                            'Set as default delivery address',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
                      onTap: () async {
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.card,
                        ),
                        child: const Center(
                          child: Text(
                            'Save Address',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
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
      appBar: AppBar(
        title: const Text(
          'Delivery Addresses',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: StreamBuilder<List<Address>>(
        stream: addressService.watchAddresses(_userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return EmptyStateView(
              icon: Icons.location_off_outlined,
              title: 'No saved addresses',
              message: 'Add your delivery address for fast 10-15 minute grocery delivery.',
              actionLabel: 'Add Address',
              onAction: () => _showAddAddressSheet(),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: addr.isDefault ? AppColors.primary : AppColors.borderLight,
                    width: addr.isDefault ? 1.5 : 1,
                  ),
                  boxShadow: AppShadows.subtle,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: addr.isDefault ? AppColors.primarySoft : AppColors.surfaceMuted,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.home_rounded,
                                size: 16,
                                color: addr.isDefault ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              addr.label,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            if (addr.isDefault) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs + 2,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(AppRadius.xs),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
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
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete', style: TextStyle(color: AppColors.saleRed)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      addr.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      addr.phone,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      addr.formattedAddress,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.3,
                      ),
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
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
