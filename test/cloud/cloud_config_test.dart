import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/cloud_config.dart';

void main() {
  group('CloudConfig', () {
    test('allows an empty development configuration', () {
      const config = CloudConfig();

      expect(config.isConfigured, isFalse);
      expect(config.isPartiallyConfigured, isFalse);
      expect(config.validate, returnsNormally);
    });

    test('requires a configured endpoint when requested', () {
      const config = CloudConfig();

      expect(
        () => config.validate(requireConfigured: true),
        throwsA(isA<FormatException>()),
      );
    });

    test('requires URL and publishable key together', () {
      const config = CloudConfig(url: 'http://127.0.0.1:54321');

      expect(config.isPartiallyConfigured, isTrue);
      expect(config.validate, throwsA(isA<FormatException>()));
    });

    test('accepts an HTTP development endpoint by default', () {
      const config = CloudConfig(
        url: 'http://127.0.0.1:54321',
        publishableKey: 'fictional-development-key',
      );

      expect(config.isConfigured, isTrue);
      expect(config.validate, returnsNormally);
    });

    test('rejects HTTP when HTTPS is required', () {
      const config = CloudConfig(
        url: 'http://127.0.0.1:54321',
        publishableKey: 'fictional-development-key',
      );

      expect(
        () => config.validate(requireHttps: true),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts HTTPS when required', () {
      const config = CloudConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'fictional-production-key',
      );

      expect(
        () => config.validate(requireConfigured: true, requireHttps: true),
        returnsNormally,
      );
    });

    test('accepts an HTTPS endpoint in its explicit host allowlist', () {
      const config = CloudConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'fictional-production-key',
        allowedHosts: ['example.supabase.co'],
      );

      expect(
        () => config.validate(
          requireConfigured: true,
          requireHttps: true,
          requireAllowedHost: true,
        ),
        returnsNormally,
      );
    });

    test(
      'rejects a production endpoint without an explicit host allowlist',
      () {
        const config = CloudConfig(
          url: 'https://example.supabase.co',
          publishableKey: 'fictional-production-key',
        );

        expect(
          () => config.validate(
            requireConfigured: true,
            requireHttps: true,
            requireAllowedHost: true,
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('rejects a host outside the explicit allowlist', () {
      const config = CloudConfig(
        url: 'https://other.supabase.co',
        publishableKey: 'fictional-production-key',
        allowedHosts: ['example.supabase.co'],
      );

      expect(
        () => config.validate(
          requireConfigured: true,
          requireHttps: true,
          requireAllowedHost: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects wildcard or URL-shaped allowlist entries', () {
      const config = CloudConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'fictional-production-key',
        allowedHosts: ['*.supabase.co'],
      );

      expect(
        () => config.validate(
          requireConfigured: true,
          requireHttps: true,
          requireAllowedHost: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects endpoint credentials, paths, queries, and fragments', () {
      const config = CloudConfig(
        url: 'https://user:password@example.supabase.co/api?x=1#fragment',
        publishableKey: 'fictional-production-key',
        allowedHosts: ['example.supabase.co'],
      );

      expect(config.validate, throwsA(isA<FormatException>()));
    });

    test('rejects a non-absolute endpoint', () {
      const config = CloudConfig(
        url: 'localhost:54321',
        publishableKey: 'fictional-development-key',
      );

      expect(config.validate, throwsA(isA<FormatException>()));
    });
  });
}
