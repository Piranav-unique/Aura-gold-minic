import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Returns the parent route when [location] was opened via [GoRouter.go] (no stack).
String? parentRouteFor(String location) {
  const directParents = <String, String>{
    '/inventory/movements': '/inventory',
    '/bank-accounts/add': '/bank-accounts',
    '/sell-gold-inquiry/success': '/user-dashboard',
    '/transactions/new': '/transactions',
    '/customers/new': '/customers',
    '/workflows/new': '/workflows',
  };
  if (directParents.containsKey(location)) {
    return directParents[location];
  }

  if (location.startsWith('/admin/sell-inquiries/') &&
      location != '/admin/sell-inquiries') {
    return '/admin/sell-inquiries';
  }

  final walletTx = RegExp(r'^/admin/user-wallets/([^/]+)/transactions$');
  final walletTxMatch = walletTx.firstMatch(location);
  if (walletTxMatch != null) {
    return '/admin/user-wallets/${walletTxMatch.group(1)}';
  }

  final walletDetail = RegExp(r'^/admin/user-wallets/([^/]+)$');
  if (walletDetail.hasMatch(location) && location != '/admin/user-wallets') {
    return '/admin/user-wallets';
  }

  final txDetail = RegExp(r'^/transactions/([^/]+)$');
  if (txDetail.hasMatch(location) && location != '/transactions') {
    return '/transactions';
  }

  final customerEdit = RegExp(r'^/customers/([^/]+)/edit$');
  final customerEditMatch = customerEdit.firstMatch(location);
  if (customerEditMatch != null) {
    return '/customers/${customerEditMatch.group(1)}';
  }

  final customerDetail = RegExp(r'^/customers/([^/]+)$');
  if (customerDetail.hasMatch(location) && location != '/customers') {
    return '/customers';
  }

  final inventoryDetail = RegExp(r'^/inventory/([^/]+)$');
  if (inventoryDetail.hasMatch(location) &&
      location != '/inventory' &&
      location != '/inventory/movements') {
    return '/inventory';
  }

  final workflowDetail = RegExp(r'^/workflows/([^/]+)$');
  if (workflowDetail.hasMatch(location) && location != '/workflows') {
    return '/workflows';
  }

  const endUserSubRoutes = <String, String>{
    '/buy-gold': '/user-dashboard',
    '/sell-gold': '/user-dashboard',
    '/sell-gold-inquiry': '/user-dashboard',
    '/my-savings': '/user-dashboard',
    '/user-transactions': '/user-dashboard',
    '/bank-accounts': '/user-dashboard',
    '/kyc': '/user-dashboard',
    '/live-price': '/user-dashboard',
    '/refer-and-earn': '/profile',
    '/settings': '/profile',
  };

  for (final entry in endUserSubRoutes.entries) {
    if (location == entry.key || location.startsWith('${entry.key}?')) {
      return entry.value;
    }
  }

  return null;
}

bool showsMobileBackButton(BuildContext context, String currentPath) {
  if (context.canPop()) return true;
  return parentRouteFor(currentPath) != null;
}

Future<void> handleAppBack(BuildContext context, String currentPath) async {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final parent = parentRouteFor(currentPath);
  if (parent != null) {
    context.go(parent);
  }
}

Widget? buildMobileLeading(BuildContext context, String currentPath) {
  if (!showsMobileBackButton(context, currentPath)) return null;
  return IconButton(
    icon: const BackButtonIcon(),
    onPressed: () => handleAppBack(context, currentPath),
  );
}
