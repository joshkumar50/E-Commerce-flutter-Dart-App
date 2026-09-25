import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:url_launcher/url_launcher.dart';

/// Data class representing an available remote application update.
class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final int currentVersionCode;
  final String latestVersion;
  final int latestVersionCode;
  final String releaseNotes;
  final String downloadUrl;
  final String? sha256;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.currentVersionCode,
    required this.latestVersion,
    required this.latestVersionCode,
    required this.releaseNotes,
    required this.downloadUrl,
    this.sha256,
    this.forceUpdate = false,
  });
}

class AppUpdateService {
  static final AppUpdateService instance = AppUpdateService._();
  AppUpdateService._();

  static const MethodChannel _channel = MethodChannel('com.bbuys.app/updater');

  /// Primary manifest URL hosted on GitHub raw (fast, cache-busting, zero API rate limits)
  static const String manifestUrl =
      'https://raw.githubusercontent.com/joshkumar50/E-Commerce-flutter-Dart-App/main/version.json';

  /// Fallback GitHub Releases REST API endpoint
  static const String githubReleasesApiUrl =
      'https://api.github.com/repos/joshkumar50/E-Commerce-flutter-Dart-App/releases/latest';

  bool _isChecking = false;
  DateTime? _lastCheckTime;

  /// Check whether an update is available.
  /// [isAdmin] specifies whether to target the Admin App or Customer App APK.
  /// If [context] is provided and an update is found, automatically displays the update dialog.
  Future<AppUpdateInfo?> checkForUpdate({
    required bool isAdmin,
    BuildContext? context,
    bool isManual = false,
  }) async {
    if (!kIsWeb && !Platform.isAndroid) {
      // Direct APK installation is specifically tailored for Android mobile builds
      if (isManual && context != null && context.mounted) {
        EasyLoading.showInfo('In-app updates are enabled for Android devices.');
      }
      return null;
    }

    if (_isChecking) return null;

    // Rate-limit automated checks to once every 15 minutes unless manually requested
    if (!isManual && _lastCheckTime != null) {
      final elapsed = DateTime.now().difference(_lastCheckTime!);
      if (elapsed.inMinutes < 15) return null;
    }

    _isChecking = true;
    if (isManual) {
      EasyLoading.show(status: 'Checking for updates…');
    }

    try {
      final localVersion = await _getLocalVersionInfo();
      final currentVersionCode = localVersion['versionCode'] as int? ?? 1;
      final currentVersionName = localVersion['versionName'] as String? ?? '1.0.0';

      final remoteManifest = await _fetchRemoteManifest(isAdmin: isAdmin);
      if (remoteManifest == null) {
        if (isManual) {
          EasyLoading.dismiss();
          EasyLoading.showInfo('Could not reach update server. Please check internet connection.');
        }
        return null;
      }

      final remoteVersionCode = remoteManifest['version_code'] as int? ?? 0;
      final remoteVersionName = remoteManifest['version_name'] as String? ?? '1.0.0';
      final releaseNotes = remoteManifest['release_notes'] as String? ?? 'New version with bug fixes and stability improvements.';
      final downloadUrl = remoteManifest['apk_url'] as String? ?? '';
      final forceUpdate = remoteManifest['force_update'] as bool? ?? false;
      final remoteSha256 = remoteManifest['sha256'] as String?;

      final hasUpdate = remoteVersionCode > currentVersionCode;

      final info = AppUpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVersionName,
        currentVersionCode: currentVersionCode,
        latestVersion: remoteVersionName,
        latestVersionCode: remoteVersionCode,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        sha256: remoteSha256,
        forceUpdate: forceUpdate,
      );

      _lastCheckTime = DateTime.now();

      if (isManual) {
        EasyLoading.dismiss();
      }

      if (hasUpdate && context != null && context.mounted) {
        showUpdateDialog(context: context, updateInfo: info);
      } else if (!hasUpdate && isManual && context != null && context.mounted) {
        _showUpToDateDialog(context, currentVersionName);
      }

      return info;
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for updates: $e');
      if (isManual) {
        EasyLoading.dismiss();
        EasyLoading.showError('Update check failed: $e');
      }
      return null;
    } finally {
      _isChecking = false;
    }
  }

  /// Download the APK from [downloadUrl] with integrity validation, retry resilience, and native installation trigger
  Future<void> downloadAndInstall({
    required String downloadUrl,
    String? expectedSha256,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
    required VoidCallback onComplete,
    required Function(String error) onError,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final cacheDirPath = await _getCacheDirectoryPath();
      final cacheDir = Directory(cacheDirPath);
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      // Purge old temporary APKs to preserve user disk space
      try {
        final existingFiles = cacheDir.listSync();
        for (final f in existingFiles) {
          if (f is File && f.path.endsWith('.apk')) {
            f.deleteSync();
          }
        }
      } catch (_) {}

      final apkFile = File('$cacheDirPath/bbuys_update_${DateTime.now().millisecondsSinceEpoch}.apk');

      // Resilient download with up to 3 automatic retries
      int attempts = 0;
      const maxAttempts = 3;
      bool downloadSuccess = false;
      String lastNetworkError = '';

      while (attempts < maxAttempts && !downloadSuccess) {
        attempts++;
        try {
          final request = await client.getUrl(Uri.parse(downloadUrl));
          request.headers.set('User-Agent', 'B-Buys-App-Updater');
          request.followRedirects = true;
          final response = await request.close();

          if (response.statusCode != 200) {
            throw HttpException('Download failed with HTTP status ${response.statusCode}');
          }

          final contentLength = response.contentLength;
          int receivedBytes = 0;
          final sink = apkFile.openWrite();

          await for (final chunk in response) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            final progress = contentLength > 0 ? (receivedBytes / contentLength).clamp(0.0, 1.0) : 0.0;
            onProgress(progress, receivedBytes, contentLength);
          }

          await sink.flush();
          await sink.close();
          downloadSuccess = true;
        } catch (e) {
          lastNetworkError = e.toString();
          debugPrint('[AppUpdateService] Download attempt $attempts failed: $e');
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: attempts));
          }
        }
      }

      if (!downloadSuccess) {
        throw HttpException('Unable to download update after $maxAttempts attempts: $lastNetworkError');
      }

      // ─── Cryptographic SHA-256 Integrity Verification ─────────────────────
      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        debugPrint('[AppUpdateService] Verifying SHA-256 checksum ($expectedSha256)...');
        final digest = await sha256.bind(apkFile.openRead()).first;
        final actualHash = digest.toString().toLowerCase();

        if (actualHash != expectedSha256.toLowerCase()) {
          try {
            apkFile.deleteSync();
          } catch (_) {}
          throw HttpException(
            'Package integrity verification failed. Expected SHA-256 $expectedSha256 but got $actualHash.',
          );
        }
        debugPrint('[AppUpdateService] SHA-256 verification passed! ✅');
      }

      onComplete();

      // Trigger native Android installation via FileProvider
      final installed = await _installApkNative(apkFile.path);
      if (!installed) {
        // Fallback to opening the browser URL if native installation prompt fails
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Download/Install error: $e');
      onError(e.toString());
    } finally {
      client.close();
    }
  }

  /// Displays the interactive in-app update dialog
  void showUpdateDialog({
    required BuildContext context,
    required AppUpdateInfo updateInfo,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (dialogCtx) => AppUpdateModalDialog(updateInfo: updateInfo),
    );
  }

  void _showUpToDateDialog(BuildContext context, String currentVersion) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 28),
            SizedBox(width: 10),
            Text('App is Up to Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'You are running the latest version of B-Buys (v$currentVersion).',
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getLocalVersionInfo() async {
    try {
      final info = await _channel.invokeMethod<Map>('getAppVersion');
      if (info != null) {
        return {
          'versionCode': (info['versionCode'] as num?)?.toInt() ?? 1,
          'versionName': info['versionName'] as String? ?? '1.0.0',
        };
      }
    } catch (_) {}
    return {'versionCode': 1, 'versionName': '1.0.0'};
  }

  Future<String> _getCacheDirectoryPath() async {
    try {
      final path = await _channel.invokeMethod<String>('getCacheDir');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return Directory.systemTemp.path;
  }

  /// Check whether the Android app has permission to install packages from unknown sources
  Future<bool> canRequestPackageInstalls() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final canInstall = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
        return canInstall ?? true;
      } catch (_) {}
    }
    return true;
  }

  /// Opens the system Android settings page for unknown app sources
  Future<void> openInstallPermissionSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openInstallPermissionSettings');
      } catch (_) {}
    }
  }

  Future<bool> _installApkNative(String filePath) async {
    try {
      final success = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return success ?? false;
    } catch (e) {
      debugPrint('[AppUpdateService] Native installApk call error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _fetchRemoteManifest({required bool isAdmin}) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    // 1. Try raw repository manifest (instant, no GitHub rate limits)
    try {
      final cacheBustedUrl = Uri.parse(
        '$manifestUrl?t=${DateTime.now().millisecondsSinceEpoch}&nonce=${DateTime.now().microsecondsSinceEpoch}',
      );
      final request = await client.getUrl(cacheBustedUrl);
      request.headers.set('User-Agent', 'B-Buys-App-Updater');
      request.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
      request.headers.set('Pragma', 'no-cache');
      request.headers.set('Expires', '0');
      request.followRedirects = true;
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final apkUrl = isAdmin
            ? (json['admin_apk_url'] as String? ?? json['customer_apk_url'] as String? ?? '')
            : (json['customer_apk_url'] as String? ?? '');

        final sha256 = isAdmin
            ? (json['admin_sha256'] as String? ?? json['sha256'] as String?)
            : (json['customer_sha256'] as String? ?? json['sha256'] as String?);

        return {
          'version_code': json['version_code'] as int? ?? 1,
          'version_name': json['version_name'] as String? ?? '1.0.0',
          'release_notes': json['release_notes'] as String? ?? 'Bug fixes and performance improvements.',
          'force_update': json['force_update'] as bool? ?? false,
          'apk_url': apkUrl,
          'sha256': sha256,
        };
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Raw manifest fetch failed: $e, trying GitHub API fallback');
    }

    // 2. Fallback: Query GitHub Releases Latest API
    try {
      final request = await client.getUrl(Uri.parse(githubReleasesApiUrl));
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'B-Buys-App-Updater');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final release = jsonDecode(body) as Map<String, dynamic>;

        final tagName = release['tag_name'] as String? ?? 'v1.0.1';
        final releaseNotes = release['body'] as String? ?? 'New version available.';

        // Parse version code from tag like v1.0.12 -> 12
        final tagNumbers = RegExp(r'(\d+)').allMatches(tagName).map((m) => int.parse(m.group(1)!)).toList();
        final parsedCode = tagNumbers.isNotEmpty ? tagNumbers.last : 1;

        final assets = release['assets'] as List<dynamic>? ?? [];
        String apkUrl = '';

        for (final asset in assets) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final downloadUrl = asset['browser_download_url'] as String? ?? '';

          if (isAdmin && (name.contains('admin') && name.endsWith('.apk'))) {
            apkUrl = downloadUrl;
            break;
          } else if (!isAdmin && (name.contains('customer') && name.endsWith('.apk'))) {
            apkUrl = downloadUrl;
            break;
          } else if (name.endsWith('.apk') && apkUrl.isEmpty) {
            apkUrl = downloadUrl;
          }
        }

        return {
          'version_code': parsedCode,
          'version_name': tagName.replaceAll('v', ''),
          'release_notes': releaseNotes,
          'force_update': false,
          'apk_url': apkUrl,
          'sha256': null,
        };
      }
    } catch (e) {
      debugPrint('[AppUpdateService] GitHub releases API fallback failed: $e');
    } finally {
      client.close();
    }

    return null;
  }
}

/// The modern in-app update interactive modal
class AppUpdateModalDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const AppUpdateModalDialog({super.key, required this.updateInfo});

  @override
  State<AppUpdateModalDialog> createState() => _AppUpdateModalDialogState();
}

class _AppUpdateModalDialogState extends State<AppUpdateModalDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;

  Future<void> _startDownload() async {
    final canInstall = await AppUpdateService.instance.canRequestPackageInstalls();
    if (!canInstall && mounted) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFF059669), size: 24),
              SizedBox(width: 8),
              Text('Permission Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'To install app updates directly, Android requires permission to install from this source.\n\nPlease tap "Open Settings" and enable "Allow from this source".',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        await AppUpdateService.instance.openInstallPermissionSettings();
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    AppUpdateService.instance.downloadAndInstall(
      downloadUrl: widget.updateInfo.downloadUrl,
      expectedSha256: widget.updateInfo.sha256,
      onProgress: (progress, received, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        }
      },
      onComplete: () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _errorMessage = err;
          });
        }
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return PopScope(
      canPop: !info.forceUpdate && !_isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon and Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    size: 40,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'New Update Available! 🚀',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'v${info.currentVersion} → v${info.latestVersion}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Release Notes Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Downloading UI or Action Buttons
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preparing package installer…',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                if (_errorMessage != null) ...[
                  Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Update Now',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!info.forceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Later',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
