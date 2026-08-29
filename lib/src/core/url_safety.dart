final class UrlSafety {
  const UrlSafety._();

  static const loopbackHosts = {'localhost', '127.0.0.1', '::1'};
  static final _ipv4 = RegExp(r'^(?:\d{1,3}\.){3}\d{1,3}$');

  static bool isLoopbackHost(String host) =>
      loopbackHosts.contains(host.trim().toLowerCase());

  /// True when the host is a literal IPv4 or IPv6 address (not a DNS name).
  static bool isNumericIpHost(String host) {
    final value = host.trim().toLowerCase();
    if (value.isEmpty) return false;
    if (_ipv4.hasMatch(value)) return true;
    return value.contains(':');
  }

  static bool isSafeHttpUri(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    final loopback = isLoopbackHost(uri.host);
    if (uri.scheme == 'http') return loopback;
    if (uri.scheme != 'https') return false;
    return loopback || !isNumericIpHost(uri.host);
  }
}
