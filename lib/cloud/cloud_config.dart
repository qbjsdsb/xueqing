class CloudConfig {
  const CloudConfig({
    this.url = '',
    this.publishableKey = '',
  });

  factory CloudConfig.fromDartDefines() {
    return CloudConfig(
      url: const String.fromEnvironment('XUEQING_SUPABASE_URL'),
      publishableKey: const String.fromEnvironment(
        'XUEQING_SUPABASE_PUBLISHABLE_KEY',
      ),
    );
  }

  final String url;
  final String publishableKey;

  bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  bool get isPartiallyConfigured =>
      url.trim().isNotEmpty != publishableKey.trim().isNotEmpty;

  void validate() {
    if (!isConfigured && !isPartiallyConfigured) {
      return;
    }

    if (isPartiallyConfigured) {
      throw const FormatException(
        'XUEQING_SUPABASE_URL and '
        'XUEQING_SUPABASE_PUBLISHABLE_KEY must be provided together.',
      );
    }

    final parsedUrl = Uri.tryParse(url.trim());
    final hasSupportedScheme =
        parsedUrl != null &&
        (parsedUrl.scheme == 'http' || parsedUrl.scheme == 'https');
    if (parsedUrl == null || parsedUrl.host.isEmpty || !hasSupportedScheme) {
      throw const FormatException(
        'XUEQING_SUPABASE_URL must be an absolute HTTP(S) URL.',
      );
    }
  }
}
