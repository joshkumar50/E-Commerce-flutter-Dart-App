import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/constants.dart';
import '../utils/observability.dart';
import 'audit_service.dart';

/// Platform service levels for high-traffic degradation and shedding
enum ServiceLevel {
  full,
  degraded,
  criticalCheckoutOnly,
}

/// Remote Configuration & Feature Flags Service
/// Provides server-controlled dynamic flags, minimum version gates, and emergency kill switches.
class RemoteConfigService {
  static final RemoteConfigService instance = RemoteConfigService._();
  RemoteConfigService._();

  // In-memory cache of config keys
  final Map<String, dynamic> _configCache = {
    'min_supported_version': {'android': '1.0.0', 'ios': '1.0.0'},
    'recommended_version': {'android': '1.0.0', 'ios': '1.0.0'},
    'service_level': 'full',
    'high_traffic_mode': false,
    'maintenance_mode': {
      'enabled': false,
      'message': 'We are currently undergoing scheduled maintenance. Please check back shortly.',
    },
    'feature_flags': {
      'recommendations': true,
      'new_checkout': true,
      'enhanced_search': true,
      'deals_banner': true,
      'review_system': false,
    },
    'kill_switches': {
      'disable_checkout': false,
      'disable_payments': false,
      'disable_refunds': false,
      'disable_realtime': false,
    },
  };

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // Stream controller to notify UI of remote config updates
  final _changeController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onChange => _changeController.stream;

  /// Load remote config from Supabase
  Future<void> fetchConfig() async {
    if (isDemoMode) {
      _isLoaded = true;
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from(tableAppConfig)
          .select('key, value, is_active')
          .eq('is_active', true);

      for (final row in rows) {
        final key = row['key'] as String;
        final value = row['value'];
        _configCache[key] = value;
      }
      _isLoaded = true;
      _changeController.add(_configCache);
    } catch (e) {
      AppObservability.warn('Failed to fetch remote config, using defaults: $e');
      _isLoaded = true;
    }
  }

  // Feature Flag Inspection

  bool isFeatureEnabled(String flagName, {bool defaultValue = false}) {
    final flags = _configCache['feature_flags'];
    if (flags is Map<String, dynamic> && flags.containsKey(flagName)) {
      return flags[flagName] == true;
    }
    return defaultValue;
  }

  // Emergency Kill Switches

  bool isKillSwitchActive(String switchName) {
    final switches = _configCache['kill_switches'];
    if (switches is Map<String, dynamic> && switches.containsKey(switchName)) {
      return switches[switchName] == true;
    }
    return false;
  }

  bool get isCheckoutDisabled => isKillSwitchActive('disable_checkout');
  bool get isPaymentsDisabled => isKillSwitchActive('disable_payments');
  bool get isRefundsDisabled => isKillSwitchActive('disable_refunds');

  // Service Levels & High-Traffic Load Shedding

  ServiceLevel get serviceLevel {
    final val = _configCache['service_level']?.toString();
    switch (val) {
      case 'degraded':
        return ServiceLevel.degraded;
      case 'critical_checkout_only':
        return ServiceLevel.criticalCheckoutOnly;
      case 'full':
      default:
        return ServiceLevel.full;
    }
  }

  bool get isHighTrafficMode => _configCache['high_traffic_mode'] == true;

  /// Returns true if heavy auxiliary systems (recommendations, banners, reviews) can run
  bool get canLoadAuxiliaryFeatures =>
      serviceLevel == ServiceLevel.full && !isHighTrafficMode;

  /// Returns true if only critical checkout and cart flows are allowed
  bool get isCriticalCheckoutOnly =>
      serviceLevel == ServiceLevel.criticalCheckoutOnly;

  // Maintenance Mode

  bool get isMaintenanceMode {
    final mm = _configCache['maintenance_mode'];
    if (mm is Map<String, dynamic>) {
      return mm['enabled'] == true;
    }
    return false;
  }

  String get maintenanceMessage {
    final mm = _configCache['maintenance_mode'];
    if (mm is Map<String, dynamic> && mm['message'] != null) {
      return mm['message'].toString();
    }
    return 'We are currently undergoing scheduled maintenance. Please check back shortly.';
  }

  // Minimum Version Gate

  bool isVersionSupported(String currentVersion, {String platform = 'android'}) {
    final minVerMap = _configCache['min_supported_version'];
    if (minVerMap is Map<String, dynamic>) {
      final minVersion = minVerMap[platform]?.toString() ?? '1.0.0';
      return _compareVersions(currentVersion, minVersion) >= 0;
    }
    return true;
  }

  int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final p1 = i < v1Parts.length ? v1Parts[i] : 0;
      final p2 = i < v2Parts.length ? v2Parts[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  // Admin Configuration Updates

  Future<bool> updateFeatureFlag(String flagName, bool enabled, {String? reason}) async {
    final flags = Map<String, dynamic>.from(_configCache['feature_flags'] as Map? ?? {});
    final previousValue = flags[flagName];
    flags[flagName] = enabled;
    _configCache['feature_flags'] = flags;

    // Log admin audit record
    await AuditService.instance.logAction(
      action: 'update_feature_flag',
      entityType: 'feature_flag',
      entityId: flagName,
      previousState: {'value': previousValue},
      newState: {'value': enabled},
      reason: reason ?? 'Toggled by administrator',
      severity: 'info',
    );

    if (isDemoMode) {
      _changeController.add(_configCache);
      return true;
    }

    try {
      await Supabase.instance.client
          .from(tableAppConfig)
          .update({
            'value': flags,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('key', 'feature_flags');
      _changeController.add(_configCache);
      return true;
    } catch (e) {
      AppObservability.error('Failed to update feature flag $flagName: $e');
      return false;
    }
  }

  Future<bool> setKillSwitch(String switchName, bool active, {String? reason}) async {
    final switches = Map<String, dynamic>.from(_configCache['kill_switches'] as Map? ?? {});
    final previousValue = switches[switchName];
    switches[switchName] = active;
    _configCache['kill_switches'] = switches;

    // Log admin audit record with high severity
    await AuditService.instance.logAction(
      action: 'toggle_kill_switch',
      entityType: 'kill_switch',
      entityId: switchName,
      previousState: {'active': previousValue},
      newState: {'active': active},
      reason: reason ?? 'Emergency kill switch adjustment',
      severity: active ? 'critical' : 'warning',
    );

    if (isDemoMode) {
      _changeController.add(_configCache);
      return true;
    }

    try {
      await Supabase.instance.client
          .from(tableAppConfig)
          .update({
            'value': switches,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('key', 'kill_switches');
      _changeController.add(_configCache);
      return true;
    } catch (e) {
      AppObservability.error('Failed to update kill switch $switchName: $e');
      return false;
    }
  }

  Future<bool> setMaintenanceMode(bool enabled, {String? message, String? reason}) async {
    final previous = _configCache['maintenance_mode'];
    final update = {
      'enabled': enabled,
      'message': message ?? maintenanceMessage,
    };
    _configCache['maintenance_mode'] = update;

    await AuditService.instance.logAction(
      action: 'toggle_maintenance_mode',
      entityType: 'maintenance_mode',
      entityId: 'global',
      previousState: previous is Map<String, dynamic> ? previous : null,
      newState: update,
      reason: reason ?? 'Maintenance window adjustment',
      severity: enabled ? 'critical' : 'info',
    );

    if (isDemoMode) {
      _changeController.add(_configCache);
      return true;
    }

    try {
      await Supabase.instance.client
          .from(tableAppConfig)
          .update({
            'value': update,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('key', 'maintenance_mode');
      _changeController.add(_configCache);
      return true;
    } catch (e) {
      AppObservability.error('Failed to update maintenance mode: $e');
      return false;
    }
  }

  Future<bool> setServiceLevel(ServiceLevel level, {String? reason}) async {
    final strVal = level == ServiceLevel.degraded
        ? 'degraded'
        : (level == ServiceLevel.criticalCheckoutOnly
            ? 'critical_checkout_only'
            : 'full');
    final previous = _configCache['service_level'];
    _configCache['service_level'] = strVal;

    await AuditService.instance.logAction(
      action: 'set_service_level',
      entityType: 'platform_service_level',
      entityId: 'global',
      previousState: {'service_level': previous},
      newState: {'service_level': strVal},
      reason: reason ?? 'Platform service level adjusted',
      severity: level == ServiceLevel.full ? 'info' : 'warning',
    );

    if (isDemoMode) {
      _changeController.add(_configCache);
      return true;
    }

    try {
      await Supabase.instance.client
          .from(tableAppConfig)
          .update({
            'value': strVal,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('key', 'service_level');
      _changeController.add(_configCache);
      return true;
    } catch (e) {
      AppObservability.error('Failed to update service level: $e');
      return false;
    }
  }

  Future<bool> setHighTrafficMode(bool enabled, {String? reason}) async {
    final previous = _configCache['high_traffic_mode'];
    _configCache['high_traffic_mode'] = enabled;

    await AuditService.instance.logAction(
      action: 'set_high_traffic_mode',
      entityType: 'platform_traffic_mode',
      entityId: 'global',
      previousState: {'high_traffic_mode': previous},
      newState: {'high_traffic_mode': enabled},
      reason: reason ?? 'High-traffic mode toggled by admin',
      severity: enabled ? 'warning' : 'info',
    );

    if (isDemoMode) {
      _changeController.add(_configCache);
      return true;
    }

    try {
      await Supabase.instance.client
          .from(tableAppConfig)
          .update({
            'value': enabled,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('key', 'high_traffic_mode');
      _changeController.add(_configCache);
      return true;
    } catch (e) {
      AppObservability.error('Failed to update high-traffic mode: $e');
      return false;
    }
  }

  Map<String, dynamic> get rawConfig => Map.unmodifiable(_configCache);
}

