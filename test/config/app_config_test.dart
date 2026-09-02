import 'package:flutter_test/flutter_test.dart';
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
      );

      expect(config.environment, AppEnvironment.production);
      expect(config.environmentLabel, 'Production');
      expect(config.appVersion, '1.2.3+4');
    });

    test('rejects an empty app version', () {
      expect(
        () => AppConfig.fromValues(appVersion: '   '),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
