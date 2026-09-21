import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../models/outbox_event.dart';
import '../../services/outbox_service.dart';

/// Transactional Outbox Inspection & Dispatcher Screen
class AdminOutboxScreen extends StatefulWidget {
  const AdminOutboxScreen({super.key});

  @override
  State<AdminOutboxScreen> createState() => _AdminOutboxScreenState();
}

class _AdminOutboxScreenState extends State<AdminOutboxScreen> {
  late Future<List<OutboxEvent>> _eventsFuture;
  OutboxStatus? _filterStatus;
  bool _isProcessingBatch = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    setState(() {
      _eventsFuture = OutboxService.instance.fetchRecentEvents(limit: 100);
    });
  }

  Future<void> _triggerBatchProcessing() async {
    setState(() => _isProcessingBatch = true);
    try {
      final res = await OutboxService.instance.processBatch(batchSize: 50);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Batch processed: ${res['processed_count'] ?? 0} published, ${res['failed_count'] ?? 0} failed',
            ),
            backgroundColor: AdminColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadEvents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process batch: $e'),
            backgroundColor: AdminColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBatch = false);
    }
  }

  Color _statusColor(OutboxStatus status) {
    switch (status) {
      case OutboxStatus.published:
        return AdminColors.accent;
      case OutboxStatus.processing:
        return AdminColors.primary;
      case OutboxStatus.pending:
        return AdminColors.warning;
      case OutboxStatus.failed:
      case OutboxStatus.deadLetter:
        return AdminColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactional Outbox Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Events',
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Action & Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AdminColors.surface,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessingBatch ? null : _triggerBatchProcessing,
                  icon: _isProcessingBatch
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_outlined, size: 16),
                  label: const Text('Process Batch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    minimumSize: const Size(130, 36),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _filterStatus == null,
                          onSelected: (_) => setState(() => _filterStatus = null),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Pending'),
                          selected: _filterStatus == OutboxStatus.pending,
                          onSelected: (_) => setState(() => _filterStatus = OutboxStatus.pending),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Published'),
                          selected: _filterStatus == OutboxStatus.published,
                          onSelected: (_) => setState(() => _filterStatus = OutboxStatus.published),
                        ),
                        const SizedBox(width: 6),
                        FilterChip(
                          label: const Text('Failed / Dead Letter'),
                          selected: _filterStatus == OutboxStatus.failed || _filterStatus == OutboxStatus.deadLetter,
                          onSelected: (_) => setState(() => _filterStatus = OutboxStatus.failed),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Events List
          Expanded(
            child: FutureBuilder<List<OutboxEvent>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AdminColors.primary));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AdminColors.danger)),
                  );
                }

                var events = snapshot.data ?? [];
                if (_filterStatus != null) {
                  if (_filterStatus == OutboxStatus.failed) {
                    events = events.where((e) => e.status == OutboxStatus.failed || e.status == OutboxStatus.deadLetter).toList();
                  } else {
                    events = events.where((e) => e.status == _filterStatus).toList();
                  }
                }

                if (events.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching outbox events found.',
                      style: TextStyle(color: AdminColors.textMuted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final e = events[index];
                    return _buildEventTile(e);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(OutboxEvent e) {
    final sColor = _statusColor(e.status);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEventDetails(e),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sColor, width: 1),
                    ),
                    child: Text(
                      e.status.name.toUpperCase(),
                      style: TextStyle(color: sColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.eventType,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    'Retries: ${e.retryCount}/${e.maxRetries}',
                    style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${e.aggregateType.toUpperCase()}: ${e.aggregateId}',
                    style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary, fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  Text(
                    e.createdAt.toLocal().toString().substring(11, 19),
                    style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                  ),
                ],
              ),
              if (e.correlationId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Trace: ${e.correlationId}',
                  style: const TextStyle(fontSize: 10, color: AdminColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetails(OutboxEvent e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text(e.eventType, style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Event ID: ${e.eventId}', style: const TextStyle(fontSize: 11, color: AdminColors.textMuted)),
              Text('Aggregate: ${e.aggregateType} #${e.aggregateId}', style: const TextStyle(fontSize: 12)),
              Text('Status: ${e.status.name}', style: TextStyle(fontSize: 12, color: _statusColor(e.status))),
              if (e.correlationId != null)
                Text('Correlation ID: ${e.correlationId}', style: const TextStyle(fontSize: 11, color: AdminColors.textMuted)),
              const SizedBox(height: 12),
              const Text('Payload:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.cardBorder),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(e.payload),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
