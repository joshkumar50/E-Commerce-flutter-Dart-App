import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opem/services/app_update_service.dart';

void main() {
  group('In-App Auto-Update Test Suite', () {
    test('AppUpdateInfo model instantiates properly with correct update status', () {
      const updateInfo = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '1.0.0',
        currentVersionCode: 1,
        latestVersion: '1.0.2',
        latestVersionCode: 2,
        releaseNotes: 'Fixed Google Sign-In and added auto-updater.',
        downloadUrl: 'https://example.com/app-customer-release.apk',
        forceUpdate: false,
      );

      expect(updateInfo.hasUpdate, isTrue);
      expect(updateInfo.currentVersion, equals('1.0.0'));
      expect(updateInfo.latestVersion, equals('1.0.2'));
      expect(updateInfo.latestVersionCode, greaterThan(updateInfo.currentVersionCode));
      expect(updateInfo.releaseNotes, contains('Google Sign-In'));
      expect(updateInfo.downloadUrl, endsWith('.apk'));
      expect(updateInfo.forceUpdate, isFalse);
    });

    test('AppUpdateInfo supports sha256 checksum field for integrity checks', () {
      const info = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '1.0.0',
        currentVersionCode: 1,
        latestVersion: '1.0.1',
        latestVersionCode: 2,
        releaseNotes: 'Security patch',
        downloadUrl: 'https://example.com/app.apk',
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(info.sha256, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
    });

    testWidgets('AppUpdateModalDialog renders version badge, release notes, and action button', (tester) async {
      const testInfo = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '1.0.0',
        currentVersionCode: 1,
        latestVersion: '1.0.5',
        latestVersionCode: 5,
        releaseNotes: 'Performance improvements and bug fixes.',
        downloadUrl: 'https://example.com/release.apk',
        forceUpdate: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppUpdateModalDialog(updateInfo: testInfo),
          ),
        ),
      );

      expect(find.text('New Update Available! 🚀'), findsOneWidget);
      expect(find.text('v1.0.0 → v1.0.5'), findsOneWidget);
      expect(find.text('Performance improvements and bug fixes.'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('AppUpdateModalDialog with forceUpdate hides the Later button', (tester) async {
      const forcedInfo = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '1.0.0',
        currentVersionCode: 1,
        latestVersion: '2.0.0',
        latestVersionCode: 10,
        releaseNotes: 'Mandatory security upgrade required.',
        downloadUrl: 'https://example.com/release.apk',
        forceUpdate: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppUpdateModalDialog(updateInfo: forcedInfo),
          ),
        ),
      );

      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
    });
  });
}
