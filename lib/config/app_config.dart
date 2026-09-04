import '../cloud/cloud_config.dart';

enum AppEnvironment {
  development('Development'),
  production('Production');

  const AppEnvironment(this.label);

  final String label;

  bool get isProduction => this == AppEnvironment.production;

  static AppEnvironment parse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'development':
      case 'dev':
        return AppEnvironment.development;
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      default:
        throw FormatException(
          'XUEQING_ENV must be development or production.',
          value,
        );
    }
  }
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appVersion,
    this.cloudConfig = const CloudConfig(),
  });

  factory AppConfig.fromDartDefines() {
    const declaredEnvironment = String.fromEnvironment('XUEQING_ENV');
    const isReleaseBuild = bool.fromEnvironment('dart.vm.product');
    const allowDevelopmentRelease = bool.fromEnvironment(
      'XUEQING_ALLOW_DEVELOPMENT_RELEASE',
      defaultValue: false,
    );
    final normalizedEnvironment = declaredEnvironment.trim();
    if (isReleaseBuild && normalizedEnvironment.isEmpty) {
      throw const FormatException(
        'XUEQING_ENV must be explicitly set for release builds.',
      );
    }

    final config = AppConfig.fromValues(
      environmentValue: normalizedEnvironment.isEmpty
          ? 'development'
          : normalizedEnvironment,
      appVersion: const String.fromEnvironment(
        'XUEQING_APP_VERSION',
        defaultValue: '0.1.0+1',
      ),
      cloudConfig: CloudConfig.fromDartDefines(),
    );
    if (isReleaseBuild &&
        !config.environment.isProduction &&
        !allowDevelopmentRelease) {
      throw const FormatException(
        'Release builds must use production environment unless '
        'XUEQING_ALLOW_DEVELOPMENT_RELEASE=true is explicitly set.',
      );
    }
    return config;
  }

  factory AppConfig.fromValues({
    String environmentValue = 'development',
    String appVersion = '0.1.0+1',
    CloudConfig cloudConfig = const CloudConfig(),
  }) {
    final environment = AppEnvironment.parse(environmentValue);
    final normalizedVersion = appVersion.trim();
    if (normalizedVersion.isEmpty) {
      throw const FormatException('XUEQING_APP_VERSION cannot be empty.');
    }
    cloudConfig.validate(
      requireConfigured: environment.isProduction,
      requireHttps: environment.isProduction,
      requireAllowedHost: environment.isProduction,
    );

    return AppConfig(
      environment: environment,
      appVersion: normalizedVersion,
      cloudConfig: cloudConfig,
    );
  }

  final AppEnvironment environment;
  final String appVersion;
  final CloudConfig cloudConfig;

  String get environmentLabel => environment.label;
}
