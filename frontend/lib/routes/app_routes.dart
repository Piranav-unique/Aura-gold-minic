import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/splash/presentation/splash_screen.dart';
import 'package:ags_gold/features/auth/domain/login_route_args.dart';
import 'package:ags_gold/features/auth/presentation/login_screen.dart';
import 'package:ags_gold/features/auth/presentation/signup_screen.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/live_price_screen.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/user_dashboard_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/buy_gold_screen.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/kyc_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/kyc_verification_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/sell_gold_inquiry_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/sell_gold_inquiry_success_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/my_savings_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/portfolio_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/user_transactions_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/bank_accounts_screen.dart';
import 'package:ags_gold/features/user_dashboard/presentation/add_bank_account_screen.dart';
import 'package:ags_gold/features/profile/presentation/profile_screen.dart';
import 'package:ags_gold/features/legal/presentation/privacy_policy_screen.dart';
import 'package:ags_gold/features/admin/presentation/metal_inventory_screen.dart';
import 'package:ags_gold/features/admin/presentation/metal_inventory_movements_screen.dart';
import 'package:ags_gold/features/admin/presentation/payment_settlements_screen.dart';
import 'package:ags_gold/features/admin/presentation/user_wallets_screen.dart';
import 'package:ags_gold/features/admin/presentation/user_wallet_detail_screen.dart';
import 'package:ags_gold/features/admin/presentation/user_wallet_transactions_screen.dart';
import 'package:ags_gold/features/admin/presentation/wallet_transaction_detail_screen.dart';
import 'package:ags_gold/features/admin/presentation/sell_inquiries_screen.dart';
import 'package:ags_gold/features/admin/presentation/sell_inquiry_detail_screen.dart';
import 'package:ags_gold/features/admin/presentation/admin_organization_profile_screen.dart';
import 'package:ags_gold/features/admin/presentation/users_screen.dart';
import 'package:ags_gold/features/admin/presentation/roles_screen.dart';
import 'package:ags_gold/features/admin/presentation/permissions_screen.dart';
import 'package:ags_gold/features/audit_logs/presentation/audit_logs_screen.dart';
import 'package:ags_gold/features/settings/presentation/settings_screen.dart';
import 'package:ags_gold/features/legal/presentation/digi_gold_terms_screen.dart';
import 'package:ags_gold/features/referral/presentation/refer_and_earn_screen.dart';
import 'package:ags_gold/features/customers/presentation/customers_screen.dart';
import 'package:ags_gold/features/customers/presentation/customer_detail_screen.dart';
import 'package:ags_gold/features/customers/presentation/customer_form_screen.dart';
import 'package:ags_gold/features/transactions/presentation/transactions_screen.dart';
import 'package:ags_gold/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:ags_gold/features/transactions/presentation/transaction_form_screen.dart';
import 'package:ags_gold/features/transactions/presentation/transaction_permission_gate.dart';
import 'package:ags_gold/features/reports/presentation/reports_screen.dart';
import 'package:ags_gold/features/reports/presentation/report_permission_gate.dart';
import 'package:ags_gold/features/workflows/presentation/workflows_screen.dart';
import 'package:ags_gold/features/workflows/presentation/workflow_detail_screen.dart';
import 'package:ags_gold/features/workflows/presentation/workflow_form_screen.dart';
import 'package:ags_gold/features/workflows/presentation/workflow_permission_gate.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import 'package:ags_gold/core/widgets/kyc_trading_gate.dart';
import 'package:ags_gold/core/widgets/permission_gate.dart';
import 'package:ags_gold/core/logging/app_event_log.dart';

String? _lastLoggedNavigationPath;

void _logNavigation(GoRouterState state) {
  final location = state.matchedLocation;
  if (location == _lastLoggedNavigationPath) return;
  final query = state.uri.queryParameters;
  AppEventLog.screen(
    location,
    from: _lastLoggedNavigationPath,
    data: query.isNotEmpty ? Map<String, Object?>.from(query) : null,
  );
  _lastLoggedNavigationPath = location;
}

/// Root navigator used for dialogs that need a localized [BuildContext].
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authNotifierProvider);
  ref.watch(appAudienceProvider);

  // Use a ValueNotifier to notify GoRouter when authentication status changes
  final listenable = ValueNotifier<int>(0);

  ref.listen<AsyncValue<AuthStatus>>(authNotifierProvider, (_, _) {
    listenable.value++;
  });
  ref.listen<AppAudience?>(appAudienceProvider, (_, _) {
    listenable.value++;
  });
  ref.listen(userKycGateProvider, (_, _) {
    listenable.value++;
  });

  ref.onDispose(() {
    listenable.dispose();
  });

  String? homeRouteForAudience(AppAudience? audience, KycStatusDetails? kyc) {
    if (audience == AppAudience.staffAdmin) return '/dashboard';
    return '/user-dashboard';
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      _logNavigation(state);

      final authValue = ref.read(authNotifierProvider);
      final status = authValue.value ?? AuthStatus.initial;
      final audience = ref.read(appAudienceProvider);
      final kycGate = ref.read(userKycGateProvider);

      final location = state.matchedLocation;
      final isSplash = location == '/';
      final isLogin = location == '/login';
      final isSignup = location == '/signup';
      final isTerms = location == '/terms-and-conditions';
      final isPrivacy = location == '/privacy-policy';
      final isPublicPage = isTerms || isPrivacy;
      final isLegacyWelcome = location == '/welcome';
      final isAuthFlow = isLegacyWelcome || isLogin || isSignup || isPublicPage;

      if (authValue.isLoading) {
        return isSplash ? null : '/';
      }

      if (authValue.hasError) {
        return isSplash ? '/login' : null;
      }

      if (status == AuthStatus.initial) {
        return isSplash ? null : '/';
      }

      if (status == AuthStatus.authenticated) {
        if (isSplash || isLegacyWelcome || isLogin || isSignup) {
          return homeRouteForAudience(audience, kycGate.asData?.value);
        }
        if (audience == AppAudience.endUser && location.startsWith('/dashboard')) {
          return '/user-dashboard';
        }
        if (audience == AppAudience.staffAdmin) {
          const endUserRoutes = [
            '/user-dashboard',
            '/portfolio',
            '/buy-gold',
            '/sell-gold',
            '/my-savings',
            '/user-transactions',
            '/bank-accounts',
            '/refer-and-earn',
            '/live-price',
            '/kyc',
          ];
          if (endUserRoutes.any(
            (route) => location == route || location.startsWith('$route/'),
          )) {
            return '/dashboard';
          }
        }
        if (audience == AppAudience.endUser) {
          const staffRoutes = [
            '/audit-logs',
            '/customers',
            '/inventory',
            '/transactions',
            '/reports',
            '/workflows',
            '/admin/',
          ];
          if (staffRoutes.any(location.startsWith)) {
            return '/user-dashboard';
          }

          final kyc = kycGate.asData?.value;
          final isTradingRoute =
              location == '/buy-gold' || location == '/sell-gold';
          if (isTradingRoute && (kyc == null || !kyc.status.isComplete)) {
            return '/user-dashboard';
          }
        }
        return null;
      }

      if (isSplash) {
        return '/login';
      }

      if (isLegacyWelcome) {
        return '/login';
      }

      if (audience == AppAudience.staffAdmin && isSignup) {
        return '/login';
      }

      if (isAuthFlow) {
        return null;
      }

      if (audience == null) {
        return '/login';
      }

      return '/login';
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/welcome', redirect: (context, state) => '/login'),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final args = LoginRouteArgs.fromExtra(state.extra);
          return LoginScreen(
            successMessage: args?.successMessage,
            initialMobile: args?.mobile,
          );
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) {
          final refCode = state.uri.queryParameters['ref'];
          final schemeRaw = state.uri.queryParameters['scheme'];
          return SignupScreen(
            initialReferralCode: refCode,
            initialReferralSchemeGrams: int.tryParse(schemeRaw ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/refer-and-earn',
        builder: (context, state) => const ReferAndEarnScreen(),
      ),
      GoRoute(
        path: '/terms-and-conditions',
        builder: (context, state) => const DigiGoldTermsScreen(),
      ),
      GoRoute(
        path: '/user-dashboard',
        builder: (context, state) => const UserDashboardScreen(),
      ),
      GoRoute(
        path: '/live-price',
        builder: (context, state) {
          final metalParam = state.uri.queryParameters['metal'];
          final initialMetal = metalParam == 'silver'
              ? MetalType.silver
              : MetalType.gold;
          return LivePriceScreen(initialMetal: initialMetal);
        },
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) => const KycVerificationScreen(),
      ),
      GoRoute(
        path: '/buy-gold',
        builder: (context, state) => KycTradingGate(
          title: AppLocalizations.of(context).buyGold,
          child: const BuyGoldScreen(),
        ),
      ),
      GoRoute(
        path: '/sell-gold-inquiry',
        builder: (context, state) => const SellGoldInquiryScreen(),
      ),
      GoRoute(
        path: '/sell-gold-inquiry/success',
        builder: (context, state) => const SellGoldInquirySuccessScreen(),
      ),
      GoRoute(
        path: '/sell-gold',
        redirect: (context, state) => '/sell-gold-inquiry',
      ),
      GoRoute(
        path: '/portfolio',
        builder: (context, state) => const PortfolioScreen(),
      ),
      GoRoute(
        path: '/my-savings',
        builder: (context, state) => const MySavingsScreen(),
      ),
      GoRoute(
        path: '/user-transactions',
        builder: (context, state) => const UserTransactionsScreen(),
      ),
      GoRoute(
        path: '/bank-accounts',
        builder: (context, state) => const BankAccountsScreen(),
      ),
      GoRoute(
        path: '/bank-accounts/add',
        builder: (context, state) => const AddBankAccountScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'dashboard.view',
          child: DashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/audit-logs',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'audit.view',
          child: AuditLogsScreen(),
        ),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'customer.view',
          child: CustomersScreen(),
        ),
      ),
      GoRoute(
        path: '/customers/new',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'customer.create',
          deniedSubtitle: 'You need customer.create to add customers.',
          child: CustomerFormScreen(),
        ),
      ),
      GoRoute(
        path: '/customers/:id/edit',
        builder: (context, state) => PermissionGate(
          requiredPermission: 'customer.update',
          deniedSubtitle: 'You need customer.update to edit customers.',
          child: CustomerFormScreen(customerId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) => PermissionGate(
          requiredPermission: 'customer.view',
          child: CustomerDetailScreen(customerId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/inventory/movements',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'inventory.view',
          child: MetalInventoryMovementsScreen(),
        ),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'inventory.view',
          child: MetalInventoryScreen(),
        ),
      ),
      GoRoute(
        path: '/inventory/:subpath',
        redirect: (context, state) => '/inventory',
      ),
      GoRoute(
        path: '/suppliers',
        redirect: (context, state) => '/inventory',
      ),
      GoRoute(
        path: '/admin/metal-inventory',
        redirect: (context, state) => '/inventory',
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) {
          final userSearch = state.uri.queryParameters['user'];
          return TransactionPermissionGate(
            requiredPermission: 'transaction.view',
            child: TransactionsScreen(initialUserSearch: userSearch),
          );
        },
      ),
      GoRoute(
        path: '/transactions/wallet-transaction',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          if (id == null || id.isEmpty) {
            return const TransactionPermissionGate(
              requiredPermission: 'transaction.view',
              child: TransactionsScreen(),
            );
          }
          return TransactionPermissionGate(
            requiredPermission: 'transaction.view',
            child: WalletTransactionDetailScreen(transactionId: id),
          );
        },
      ),
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => const TransactionPermissionGate(
          requiredPermission: 'transaction.create',
          deniedSubtitle: 'You need transaction.create to add transactions.',
          child: TransactionFormScreen(),
        ),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        builder: (context, state) => TransactionPermissionGate(
          requiredPermission: 'transaction.update',
          deniedSubtitle: 'You need transaction.update to edit transactions.',
          child: TransactionFormScreen(
            transactionId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (context, state) => TransactionPermissionGate(
          requiredPermission: 'transaction.view',
          child: TransactionDetailScreen(
            transactionId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) =>
            const ReportPermissionGate(child: ReportsScreen()),
      ),
      GoRoute(
        path: '/workflows',
        builder: (context, state) => const WorkflowPermissionGate(
          requiredPermission: 'workflow.view',
          child: WorkflowsScreen(),
        ),
      ),
      GoRoute(
        path: '/workflows/new',
        builder: (context, state) => const WorkflowPermissionGate(
          requiredPermission: 'workflow.create',
          deniedSubtitle: 'You need workflow.create to create requests.',
          child: WorkflowFormScreen(),
        ),
      ),
      GoRoute(
        path: '/workflows/:id/edit',
        builder: (context, state) => WorkflowPermissionGate(
          requiredPermission: 'workflow.create',
          deniedSubtitle: 'You need workflow.create to edit requests.',
          child: WorkflowFormScreen(requestId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/workflows/:id',
        builder: (context, state) => WorkflowPermissionGate(
          requiredPermission: 'workflow.view',
          child: WorkflowDetailScreen(requestId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin/user-wallets',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'wallet.view',
          child: UserWalletsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/user-wallets/:userId',
        builder: (context, state) => PermissionGate(
          requiredPermission: 'wallet.view',
          child: UserWalletDetailScreen(
            userId: state.pathParameters['userId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/admin/user-wallets/:userId/transactions',
        builder: (context, state) => PermissionGate(
          requiredPermission: 'wallet.view',
          child: UserWalletTransactionsScreen(
            userId: state.pathParameters['userId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/admin/payment-settlements',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'transaction.view',
          child: PaymentSettlementsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/sell-inquiries',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'transaction.view',
          child: SellInquiriesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/sell-inquiries/:id',
        builder: (context, state) => PermissionGate(
          requiredPermission: 'transaction.view',
          child: SellInquiryDetailScreen(
            inquiryId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/admin/profile',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'organization.view',
          child: AdminOrganizationProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'user.view',
          child: UsersScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/roles',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'role:read',
          child: RolesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/permissions',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'role:read',
          child: PermissionsScreen(),
        ),
      ),
    ],
  );
});
