import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opem/models/product.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/product_service.dart';
import 'package:opem/widgets/drawer.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

/// Allows a user (or admin) to create a new product listing.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _cityController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  File? _imageFile;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 640,
      maxHeight: 480,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_imageFile == null) {
      EasyLoading.showError('Please choose a product image.');
      return;
    }

    final userProvider = context.read<UserProvider>();
    EasyLoading.show(status: 'Publishing…');
    try {
      final pid = _uuid.v4();
      final bytes = await _imageFile!.readAsBytes();
      final imageUrl = await productService.uploadImage(
        fileName: pid,
        bytes: bytes,
      );

      final product = Product(
        id: 0, // assigned by DB
        pid: pid,
        title: _nameController.text.trim(),
        description: _descController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        owner: userProvider.id ?? '',
        city: _cityController.text.trim(),
        image: imageUrl,
      );
      await productService.addProduct(product);

      EasyLoading.showSuccess('Product published!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      EasyLoading.showError('Failed to publish: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      drawer: const GlobalDrawer(pageIndex: 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40),
                              SizedBox(height: 8),
                              Text('Tap to choose image'),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _field(_nameController, 'Product Name'),
              const SizedBox(height: 12),
              _field(_descController, 'Description', maxLines: 3),
              const SizedBox(height: 12),
              _field(_priceController, 'Price (USD)',
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') == null
                      ? 'Enter a valid price'
                      : null),
              const SizedBox(height: 12),
              _field(_cityController, 'City'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _publish,
                  child: const Text('Publish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
