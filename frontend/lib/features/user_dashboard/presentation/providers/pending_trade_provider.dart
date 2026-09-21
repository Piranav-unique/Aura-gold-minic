import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/services/service_providers.dart';

class PendingTrade {
  final bool isBuy;
  final MetalType metal;

  const PendingTrade({required this.isBuy, required this.metal});

  String get routePath {
    final metalParam = metal == MetalType.silver ? 'silver' : 'gold';
    return isBuy ? '/buy-gold?metal=$metalParam' : '/sell-gold?metal=$metalParam';
  }
}

class PendingTradeNotifier extends Notifier<PendingTrade?> {
  @override
  PendingTrade? build() {
    ref.listen(authNotifierProvider, (previous, next) {
      final status = next.value;
      if (status != null && status != AuthStatus.authenticated) {
        state = null;
      }
    });
    return null;
  }

  void set(PendingTrade? trade) => state = trade;

  void clear() => state = null;
}

final pendingTradeProvider =
    NotifierProvider<PendingTradeNotifier, PendingTrade?>(
      PendingTradeNotifier.new,
    );
