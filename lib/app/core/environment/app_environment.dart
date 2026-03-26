class AppEnvironment {
  AppEnvironment._();

  static const String _configuredResolverEndpoint = String.fromEnvironment(
    'RESOLVER_ENDPOINT',
    defaultValue: '',
  );

  static String get resolverEndpoint {
    if (_configuredResolverEndpoint.isNotEmpty) {
      return _configuredResolverEndpoint;
    }

    return 'https://videodownloaderbackend-production-99d3.up.railway.app/resolve';
  }
}
