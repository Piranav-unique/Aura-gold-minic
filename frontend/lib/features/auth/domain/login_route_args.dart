class LoginRouteArgs {
  final String? successMessage;
  final String? mobile;

  const LoginRouteArgs({this.successMessage, this.mobile});

  static LoginRouteArgs? fromExtra(Object? extra) {
    if (extra is LoginRouteArgs) return extra;
    if (extra is Map) {
      return LoginRouteArgs(
        successMessage: extra['successMessage'] as String?,
        mobile: extra['mobile'] as String?,
      );
    }
    if (extra is String) {
      return LoginRouteArgs(successMessage: extra);
    }
    return null;
  }
}
