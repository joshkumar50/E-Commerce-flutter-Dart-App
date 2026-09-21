import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/models/category.dart';
import 'package:opem/services/category_service.dart';
import 'package:opem/services/storage_service.dart';

class AdminCategoryFormScreen extends StatefulWidget {
  final Category? category;

  const AdminCategoryFormScreen({super.key, this.category});

  @override
  State<AdminCategoryFormScreen> createState() => _AdminCategoryFormScreenState();
}

class _AdminCategoryFormScreenState extends State<AdminCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;
  late TextEditingController _sortOrderController;

  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _nameController = TextEditingController(text: c?.name ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _imageUrlController = TextEditingController(text: c?.imageUrl ?? '');
    _sortOrderController = TextEditingController(text: c != null ? c.sortOrder.toString() : '1');
    _isActive = c?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await picked.readAsBytes();
      final url = await storageService.uploadProductImage(
        productId: 9999, // General category folder
        fileName: 'cat_${picked.name}',
        bytes: bytes,
      );

      if (mounted) {
        setState(() {
          _imageUrlController.text = url;
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category image uploaded'),
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
            content: Text('Image upload failed: $e'),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await categoryService.updateCategory(widget.category!.id, {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'image_url': _imageUrlController.text.trim(),
          'sort_order': sortOrder,
          'is_active': _isActive,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated category "${_nameController.text.trim()}"'),
              backgroundColor: AdminColors.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        final newCategory = Category(
          id: '',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isNotEmpty
              ? _imageUrlController.text.trim()
              : 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=640&q=80',
          sortOrder: sortOrder,
          isActive: _isActive,
        );

        await categoryService.createCategory(newCategory);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created category "${newCategory.name}"'),
              backgroundColor: AdminColors.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving category: $e'),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Category' : 'Add Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Image Preview & Pick Card ──────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AdminColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.cardBorder),
                      ),
                      child: _isUploadingImage
                          ? const Center(child: CircularProgressIndicator(color: AdminColors.primary))
                          : (_imageUrlController.text.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _imageUrlController.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.category_outlined, color: AdminColors.textMuted),
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AdminColors.textMuted)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Choose Image'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Or Image URL',
                        prefixIcon: Icon(Icons.link),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Fields Card ────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name *',
                        hintText: 'e.g. Dairy & Eggs',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Category name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'e.g. Farm-fresh milk, butter, cheese, and eggs',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _sortOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Display Sort Order *',
                        hintText: 'Lower numbers display first (e.g. 1, 2, 3)',
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        if (int.tryParse(val.trim()) == null) return 'Must be an integer';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
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
                                _isActive ? 'Category Active' : 'Category Hidden',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                _isActive ? 'Visible to customers in store' : 'Hidden from customer store',
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

            // ─── Save Button ────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _isSaving ? null : _saveCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _isEditing ? 'Save Category Changes' : 'Create Category',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
