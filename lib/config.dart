const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

/// Parsed [Uri] for the configured API base URL.
final Uri apiBaseUri = Uri.parse(apiBaseUrl);

const Set<String> _loopbackHosts = {'localhost', '127.0.0.1', '0.0.0.0'};

/// Replace loopback hosts with the configured API host so physical devices
/// and emulators can resolve local development assets.
Uri normalizeLoopback(Uri uri) {
  if (!_loopbackHosts.contains(uri.host)) return uri;
  final fallback = apiBaseUri;
  return uri.replace(
    scheme: fallback.scheme.isNotEmpty ? fallback.scheme : uri.scheme,
    host: fallback.host.isNotEmpty ? fallback.host : uri.host,
    port: fallback.hasPort ? fallback.port : (uri.hasPort ? uri.port : null),
  );
}

/// Ensure the final URL is absolute and uses the configured API origin.
String resolveMediaUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return '';

  final maybeUri = Uri.tryParse(trimmed);
  if (maybeUri != null && maybeUri.hasScheme) {
    return normalizeLoopback(maybeUri).toString();
  }

  var origin = apiBaseUrl;
  if (origin.endsWith('/api')) origin = origin.substring(0, origin.length - 4);
  final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  final resolved = path.startsWith('storage/') ? '$origin/$path' : '$origin/storage/$path';
  return resolved;
}
