import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/admin_audit_log.dart';
import '../../services/audit_service.dart';

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  bool _isLoading = true;
  List<AdminAuditLog> _logs = [];
  String _selectedEntityType = 'All';
  String _selectedSeverity = 'All';

  final List<String> _entityTypes = [
    'All',
    'product',
    'inventory',
    'order',
    'feature_flag',
    'kill_switch',
    'maintenance_mode'
  ];

  final List<String> _severities = ['All', 'info', 'warning', 'critical'];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final logs = await AuditService.instance.fetchAuditLogs(
      entityType: _selectedEntityType == 'All' ? null : _selectedEntityType,
      severity: _selectedSeverity == 'All' ? null : _selectedSeverity,
      limit: 100,
    );
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Audit & Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: 'Refresh Audit Log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('Entity: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedEntityType,
                    underline: const SizedBox(),
                    items: _entityTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedEntityType = val);
                        _fetchLogs();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Severity: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                DropdownButton<String>(
                  value: _selectedSeverity,
                  underline: const SizedBox(),
                  items: _severities.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSeverity = val);
                      _fetchLogs();
                    }
                  },
                ),
              ],
            ),
          ),

          // Log List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No audit records found', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchLogs,
                        child: ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final log = _logs[idx];
                            return _buildAuditItem(log);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditItem(AdminAuditLog log) {
    final color = _severityColor(log.severity);

    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          log.severity == 'critical'
              ? Icons.warning_amber_rounded
              : (log.severity == 'warning' ? Icons.info_outline : Icons.history),
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        log.action.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        '${log.entityType} #${log.entityId} • by ${log.actorEmail ?? 'Admin'}',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: Text(
        '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (log.reason != null && log.reason!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.comment, size: 14, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text('Reason: ${log.reason}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (log.previousState != null || log.newState != null) ...[
                const Text('State Transition:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                if (log.previousState != null)
                  Text(
                    'Before: ${jsonEncode(log.previousState)}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontFamily: 'monospace'),
                  ),
                if (log.newState != null)
                  Text(
                    'After:  ${jsonEncode(log.newState)}',
                    style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontFamily: 'monospace'),
                  ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: ${log.createdAt.toLocal().toString().split('.')[0]}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (log.requestId != null)
                    Text(
                      'Req: ${log.requestId}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
