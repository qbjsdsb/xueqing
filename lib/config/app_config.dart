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
    return AppConfig.fromValues(
      environmentValue: const String.fromEnvironment(
        'XUEQING_ENV',
        defaultValue: 'development',
      ),
      appVersion: const String.fromEnvironment(
        'XUEQING_APP_VERSION',
        defaultValue: '0.1.0+1',
      ),
      cloudConfig: CloudConfig.fromDartDefines(),
    );
  }

  factory AppConfig.fromValues({
    String environmentValue = 'development',
    String appVersion = '0.1.0+1',
    CloudConfig cloudConfig = const CloudConfig(),
  }) {
    final normalizedVersion = appVersion.trim();
    if (normalizedVersion.isEmpty) {
      throw const FormatException('XUEQING_APP_VERSION cannot be empty.');
    }
    cloudConfig.validate();

    return AppConfig(
      environment: AppEnvironment.parse(environmentValue),
      appVersion: normalizedVersion,
      cloudConfig: cloudConfig,
    );
  }

  final AppEnvironment environment;
  final String appVersion;
  final CloudConfig cloudConfig;

  String get environmentLabel => environment.label;
}
