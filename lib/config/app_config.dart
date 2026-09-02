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
  const AppConfig({required this.environment, required this.appVersion});

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
    );
  }

  factory AppConfig.fromValues({
    String environmentValue = 'development',
    String appVersion = '0.1.0+1',
  }) {
    final normalizedVersion = appVersion.trim();
    if (normalizedVersion.isEmpty) {
      throw const FormatException('XUEQING_APP_VERSION cannot be empty.');
    }

    return AppConfig(
      environment: AppEnvironment.parse(environmentValue),
      appVersion: normalizedVersion,
    );
  }

  final AppEnvironment environment;
  final String appVersion;

  String get environmentLabel => environment.label;
}
