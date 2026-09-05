import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/cloud_config.dart';
import 'package:xueqing/config/app_config.dart';

void main() {
  group('AppEnvironment', () {
    test('parses development and production values', () {
      expect(AppEnvironment.parse('development'), AppEnvironment.development);
      expect(AppEnvironment.parse('dev'), AppEnvironment.development);
      expect(AppEnvironment.parse('production'), AppEnvironment.production);
      expect(AppEnvironment.parse('prod'), AppEnvironment.production);
    });

    test('rejects unknown values', () {
      expect(
        () => AppEnvironment.parse('staging'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AppConfig', () {
    test('uses the typed values supplied by the build', () {
      final config = AppConfig.fromValues(
        environmentValue: 'production',
        appVersion: '1.2.3+4',
        cloudConfig: const CloudConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'fictional-production-key',
          allowedHosts: ['example.supabase.co'],
        ),
      );

      expect(config.environment, AppEnvironment.production);
      expect(config.environmentLabel, 'Production');
      expect(config.appVersion, '1.2.3+4');
      expect(config.showDeveloperTools, isFalse);
    });


    test('can explicitly hide developer tools in a development build', () {
      final config = AppConfig.fromValues(
        environmentValue: 'development',
        appVersion: '1.2.3+4',
        showDeveloperTools: false,
      );

      expect(config.showDeveloperTools, isFalse);
    });

    test('rejects a production config without a cloud endpoint', () {
      expect(
        () => AppConfig.fromValues(
          environmentValue: 'production',
          appVersion: '1.2.3+4',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an HTTP production endpoint', () {
      expect(
        () => AppConfig.fromValues(
          environmentValue: 'production',
          appVersion: '1.2.3+4',
          cloudConfig: const CloudConfig(
            url: 'http://127.0.0.1:54321',
            publishableKey: 'fictional-production-key',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a production endpoint without a host allowlist', () {
      expect(
        () => AppConfig.fromValues(
          environmentValue: 'production',
          appVersion: '1.2.3+4',
          cloudConfig: const CloudConfig(
            url: 'https://example.supabase.co',
            publishableKey: 'fictional-production-key',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an empty app version', () {
      expect(
        () => AppConfig.fromValues(appVersion: '   '),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
