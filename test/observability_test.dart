import 'package:flutter_test/flutter_test.dart';
import 'package:opem/utils/observability.dart';

void main() {
  group('AppObservability.sanitize', () {
    test('redacts simple sensitive keys', () {
      final input = {'password': 'super_secret', 'normal': 'value'};
      final result = AppObservability.sanitize(input);
      expect(result['password'], '[REDACTED]');
      expect(result['normal'], 'value');
    });

    test('redacts nested sensitive keys', () {
      final input = {
        'user': {
          'email': 'test@example.com',
          'phone': '1234567890',
          'name': 'Test User'
        }
      };
      final result = AppObservability.sanitize(input);
      expect(result['user']['email'], '[REDACTED]');
      expect(result['user']['phone'], '[REDACTED]');
      expect(result['user']['name'], 'Test User'); // 'name' is not redacted directly unless it is full_name
    });

    test('redacts JWTs in string values', () {
      final input = {'msg': 'Bearer eyJhbGciOiJIUzI1Ni.eyJzdWIiOi.SflKxwRJSMeKKF2'};
      final result = AppObservability.sanitize(input);
      expect(result['msg'], 'Bearer [REDACTED_JWT]');
    });

    test('redacts JWTs in deeply nested list values', () {
      final input = {
        'events': [
          {'data': 'Normal string'},
          {'message_info': 'Token is eyJhbGciOiJIUzI1Ni.eyJzdWIiOi.SflKxwRJSMeKKF2'}
        ]
      };
      final result = AppObservability.sanitize(input);
      expect(result['events'][0]['data'], 'Normal string');
      expect(result['events'][1]['message_info'], 'Token is [REDACTED_JWT]');
    });
  });
}
