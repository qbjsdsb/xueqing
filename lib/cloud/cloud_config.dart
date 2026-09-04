class CloudConfig {
  const CloudConfig({
    this.url = '',
    this.publishableKey = '',
    this.allowedHosts = const <String>[],
  });

  factory CloudConfig.fromDartDefines() {
    const rawAllowedHosts = String.fromEnvironment(
      'XUEQING_SUPABASE_ALLOWED_HOSTS',
    );
    return CloudConfig(
      url: const String.fromEnvironment('XUEQING_SUPABASE_URL'),
      publishableKey: const String.fromEnvironment(
        'XUEQING_SUPABASE_PUBLISHABLE_KEY',
      ),
      allowedHosts: _parseAllowedHosts(rawAllowedHosts),
    );
  }

  static List<String> _parseAllowedHosts(String value) {
    return value
        .split(',')
        .map((host) => host.trim())
        .where((host) => host.isNotEmpty)
        .toList(growable: false);
  }

  final String url;
  final String publishableKey;
  final List<String> allowedHosts;

  bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  bool get isPartiallyConfigured =>
      url.trim().isNotEmpty != publishableKey.trim().isNotEmpty;

  void validate({
    bool requireConfigured = false,
    bool requireHttps = false,
    bool requireAllowedHost = false,
  }) {
    if (!isConfigured && !isPartiallyConfigured) {
      if (requireConfigured) {
        throw const FormatException(
          'XUEQING_SUPABASE_URL and '
          'XUEQING_SUPABASE_PUBLISHABLE_KEY must be configured.',
        );
      }
      return;
    }

    if (isPartiallyConfigured) {
      throw const FormatException(
        'XUEQING_SUPABASE_URL and '
        'XUEQING_SUPABASE_PUBLISHABLE_KEY must be provided together.',
      );
    }

    final parsedUrl = Uri.tryParse(url.trim());
    final scheme = parsedUrl?.scheme.toLowerCase();
    final host = parsedUrl?.host.toLowerCase();
    final hasSupportedScheme =
        parsedUrl != null && (scheme == 'http' || scheme == 'https');
    final hasUnexpectedComponents =
        parsedUrl != null &&
        (parsedUrl.userInfo.isNotEmpty ||
            (parsedUrl.path.isNotEmpty && parsedUrl.path != '/') ||
            parsedUrl.query.isNotEmpty ||
            parsedUrl.fragment.isNotEmpty);
    if (parsedUrl == null ||
        host == null ||
        host.isEmpty ||
        !hasSupportedScheme ||
        hasUnexpectedComponents) {
      throw const FormatException(
        'XUEQING_SUPABASE_URL must be an absolute HTTP(S) URL '
        'without credentials, path, query, or fragment.',
      );
    }

    final normalizedAllowedHosts = <String>{};
    for (final allowedHost in allowedHosts) {
      normalizedAllowedHosts.add(_normalizeAllowedHost(allowedHost));
    }

    if (requireHttps && scheme != 'https') {
      throw const FormatException(
        'XUEQING_SUPABASE_URL must use HTTPS for this environment.',
      );
    }

    if (requireAllowedHost) {
      if (normalizedAllowedHosts.isEmpty) {
        throw const FormatException(
          'XUEQING_SUPABASE_ALLOWED_HOSTS must contain the production host.',
        );
      }
      if (!normalizedAllowedHosts.contains(host)) {
        throw const FormatException(
          'XUEQING_SUPABASE_URL host is not in '
          'XUEQING_SUPABASE_ALLOWED_HOSTS.',
        );
      }
    }
  }

  static String _normalizeAllowedHost(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized.contains('/') ||
        normalized.contains('?') ||
        normalized.contains('#') ||
        normalized.contains('@') ||
        normalized.contains(':') ||
        normalized.contains('*')) {
      throw const FormatException(
        'XUEQING_SUPABASE_ALLOWED_HOSTS must contain host names only.',
      );
    }

    final parsed = Uri.tryParse('https://$normalized');
    if (parsed == null || parsed.host != normalized || parsed.host.isEmpty) {
      throw const FormatException(
        'XUEQING_SUPABASE_ALLOWED_HOSTS contains an invalid host.',
      );
    }
    return normalized;
  }
}
