import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/models/category.dart';
import 'package:opem/models/product.dart';
import 'package:opem/models/product_image.dart';
import 'package:opem/services/category_service.dart';
import 'package:opem/services/product_image_service.dart';
import 'package:opem/services/product_service.dart';
import 'package:opem/services/storage_service.dart';

class AdminProductFormScreen extends StatefulWidget {
  final Product? product;

  const AdminProductFormScreen({super.key, this.product});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _salePriceController;
  late TextEditingController _stockController;
  late TextEditingController _unitController;
  late TextEditingController _imageUrlController;

  String? _selectedCategoryId;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  int? _currentVersion;
  String? _concurrencyError;

  List<ProductImage> _secondaryImages = [];
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _currentVersion = p?.version;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _salePriceController = TextEditingController(
      text: (p != null && p.salePrice != null) ? p.salePrice!.toStringAsFixed(2) : '',
    );
    _stockController = TextEditingController(text: p != null ? p.stockQuantity.toString() : '50');
    _unitController = TextEditingController(text: p?.unit ?? '1 kg');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');
    _selectedCategoryId = p?.categoryId;
    _isActive = p?.isActive ?? true;

    if (_isEditing) {
      _loadSecondaryImages();
    }
  }

  Future<void> _loadSecondaryImages() async {
    if (widget.product == null) return;
    try {
      final list = await productImageService.fetchProductImages(widget.product!.id);
      if (mounted) setState(() => _secondaryImages = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await picked.readAsBytes();
      final fileName = picked.name;

      final url = await storageService.uploadProductImage(
        productId: widget.product?.id ?? DateTime.now().millisecondsSinceEpoch,
        fileName: fileName,
        bytes: bytes,
      );

      if (mounted) {
        setState(() {
          _imageUrlController.text = url;
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product image uploaded successfully'),
            backgroundColor: AdminColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final salePriceText = _salePriceController.text.trim();
    final salePrice = salePriceText.isNotEmpty ? double.tryParse(salePriceText) : null;

    if (salePrice != null && salePrice > price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale price cannot exceed regular price.'),
          backgroundColor: AdminColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final stock = int.tryParse(_stockController.text.trim()) ?? 0;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        // Update existing product
        final updates = <String, dynamic>{
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category_id': _selectedCategoryId,
          'price': price,
          'sale_price': salePrice,
          'stock_quantity': stock,
          'unit': _unitController.text.trim(),
          'image_url': _imageUrlController.text.trim(),
          'is_active': _isActive,
        };

        await productService.updateProduct(
          widget.product!.id,
          updates,
          expectedVersion: _currentVersion ?? widget.product!.version,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated "${_nameController.text.trim()}" successfully'),
              backgroundColor: AdminColors.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        // Create new product
        final newProduct = Product(
          id: 0,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _selectedCategoryId,
          price: price,
          salePrice: salePrice,
          stockQuantity: stock,
          unit: _unitController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isNotEmpty
              ? _imageUrlController.text.trim()
              : 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=640&q=80',
          isActive: _isActive,
        );

        await productService.createProduct(newProduct);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created "${newProduct.name}" successfully'),
              backgroundColor: AdminColors.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } on StaleVersionException catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _concurrencyError = e.message;
        });
        _showConflictDialog(e.currentVersion);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e'),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reloadProductData() async {
    if (widget.product == null) return;
    setState(() => _isSaving = true);
    try {
      final fresh = await productService.fetchProductById(widget.product!.id);
      if (fresh != null && mounted) {
        setState(() {
          _nameController.text = fresh.name;
          _descriptionController.text = fresh.description;
          _priceController.text = fresh.price.toStringAsFixed(2);
          _salePriceController.text =
              fresh.salePrice != null ? fresh.salePrice!.toStringAsFixed(2) : '';
          _stockController.text = fresh.stockQuantity.toString();
          _unitController.text = fresh.unit;
          _imageUrlController.text = fresh.imageUrl;
          _selectedCategoryId = fresh.categoryId;
          _isActive = fresh.isActive;
          _currentVersion = fresh.version;
          _concurrencyError = null;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reloaded product to latest server state (version ${fresh.version})'),
            backgroundColor: AdminColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reload product: $e'),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showConflictDialog(int serverVersion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AdminColors.warning),
            SizedBox(width: 8),
            Text('Edit Conflict (OCC)', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Another administrator saved updates to this product while you were editing.\n\n'
          'Server Version: $serverVersion\n'
          'Your Form Version: ${_currentVersion ?? 1}\n\n'
          'To prevent silently overwriting their changes, please reload the latest data before making your modifications.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Review Form', style: TextStyle(color: AdminColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _reloadProductData();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reload Latest'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add New Product'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AdminColors.dangerLight),
              tooltip: 'Delete Product',
              onPressed: () => _confirmDelete(),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_concurrencyError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.warning, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AdminColors.warning, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Concurrent Edit Conflict (OCC)',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.warning, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _concurrencyError!,
                            style: const TextStyle(fontSize: 12, color: AdminColors.textPrimary),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _reloadProductData,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Reload Latest Version'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminColors.warning,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(120, 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Image Preview & Uploader Card ──────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Image',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AdminColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminColors.cardBorder, width: 1.5),
                        ),
                        child: _isUploadingImage
                            ? const Center(
                                child: CircularProgressIndicator(color: AdminColors.primary),
                              )
                            : (_imageUrlController.text.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _imageUrlController.text,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image, color: AdminColors.textMuted, size: 36),
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.add_a_photo_outlined, color: AdminColors.textMuted, size: 36),
                                  )),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isUploadingImage ? null : () => _pickAndUploadImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(100, 36)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _isUploadingImage ? null : () => _pickAndUploadImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(100, 36)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Or Paste Image URL',
                        prefixIcon: Icon(Icons.link),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_secondaryImages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Gallery Images',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _secondaryImages.length,
                          itemBuilder: (context, i) {
                            final img = _secondaryImages[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  img.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Basic Details Card ─────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General Information',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        hintText: 'e.g. Organic Cavendish Bananas',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Category Dropdown
                    StreamBuilder<List<Category>>(
                      stream: categoryService.watchAllCategories(),
                      builder: (context, catSnap) {
                        final categories = catSnap.data ?? [];

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Unit
                    TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit / Packaging *',
                        hintText: 'e.g. 1 kg, 500g, 1 Litre, Pack of 3',
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Unit description is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Freshness details, origin, or dietary notes...',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Pricing & Stock Card ───────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pricing & Inventory',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Price & Sale Price
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price (\$) *',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Required';
                              }
                              final num = double.tryParse(val.trim());
                              if (num == null || num < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _salePriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Sale Price (\$) (Opt)',
                              prefixIcon: Icon(Icons.local_offer_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return null;
                              final num = double.tryParse(val.trim());
                              if (num == null || num < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Stock Quantity
                    TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock Quantity *',
                        prefixIcon: Icon(Icons.warehouse_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Stock quantity is required';
                        }
                        final num = int.tryParse(val.trim());
                        if (num == null || num < 0) {
                          return 'Enter a non-negative whole number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Active Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AdminColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isActive ? 'Product Active' : 'Product Inactive',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                _isActive
                                    ? 'Visible to customers in grocery store'
                                    : 'Hidden from customer store listings',
                                style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isActive,
                            activeThumbColor: AdminColors.accent,
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Save Action Button ─────────────────────────────────────────
            ElevatedButton(
              onPressed: _isSaving ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEditing ? 'Save Changes' : 'Create Product',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${widget.product!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await productService.deleteProduct(
                id: widget.product!.id,
                imageUrl: widget.product!.imageUrl,
              );
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
