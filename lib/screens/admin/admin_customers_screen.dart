import 'package:flutter/material.dart';
import 'package:opem/core/admin_theme.dart';
import 'package:opem/models/profile.dart';
import 'package:opem/services/profile_service.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Profile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _refreshProfiles();
  }

  void _refreshProfiles() {
    setState(() {
      _profilesFuture = profileService.fetchAllProfiles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _refreshProfiles,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search Bar ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search customers by name or email...',
                prefixIcon: const Icon(Icons.search, color: AdminColors.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const Divider(height: 1, color: AdminColors.cardBorder),

          // ─── Customers List ─────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<Profile>>(
              future: _profilesFuture,
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
                          const Icon(Icons.error_outline, size: 48, color: AdminColors.danger),
                          const SizedBox(height: 12),
                          Text('Failed to load customers: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshProfiles,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                var list = snapshot.data ?? [];

                if (_searchQuery.isNotEmpty) {
                  list = list
                      .where((p) =>
                          p.fullName.toLowerCase().contains(_searchQuery) ||
                          p.email.toLowerCase().contains(_searchQuery) ||
                          p.phone.contains(_searchQuery))
                      .toList();
                }

                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 56, color: AdminColors.textMuted),
                          SizedBox(height: 16),
                          Text(
                            'No customers found',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'New customers will appear here when they register in the shopping app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final profile = list[index];
                    final isAdmin = profile.role == 'admin';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isAdmin ? AdminColors.accentLight : AdminColors.infoLight,
                              backgroundImage: profile.avatarUrl.isNotEmpty
                                  ? NetworkImage(profile.avatarUrl)
                                  : null,
                              child: profile.avatarUrl.isEmpty
                                  ? Text(
                                      profile.fullName.isNotEmpty
                                          ? profile.fullName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: isAdmin ? AdminColors.accentDark : AdminColors.info,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),

                            // Customer Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          profile.fullName.isNotEmpty ? profile.fullName : 'Unnamed User',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AdminColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isAdmin ? AdminColors.accentLight : AdminColors.background,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isAdmin ? AdminColors.accent : AdminColors.cardBorder,
                                          ),
                                        ),
                                        child: Text(
                                          profile.role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isAdmin ? AdminColors.accentDark : AdminColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    profile.email,
                                    style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (profile.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Phone: ${profile.phone}',
                                      style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
