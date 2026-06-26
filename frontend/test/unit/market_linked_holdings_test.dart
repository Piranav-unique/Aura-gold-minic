import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/user_dashboard/domain/market_linked_holdings.dart';

void main() {
  group('MarketLinkedHoldings', () {
    test('display grams match stored at purchase rate', () {
      const stored = 0.0660;
      const invested = 970.0;
      const purchaseRate = invested / stored;

      final linked = MarketLinkedHoldings.marketLinkedGrams(
        storedGrams: stored,
        investedInr: invested,
        liveRatePerGram: purchaseRate,
      );

      expect(linked, closeTo(stored, 0.0001));
    });

    test('display grams rise when live rate rises', () {
      const stored = 0.0660;
      const invested = 970.0;

      final linked = MarketLinkedHoldings.marketLinkedGrams(
        storedGrams: stored,
        investedInr: invested,
        liveRatePerGram: 15000,
      );

      expect(linked, greaterThan(stored));
    });

    test('display grams fall when live rate falls', () {
      const stored = 0.0660;
      const invested = 970.0;

      final linked = MarketLinkedHoldings.marketLinkedGrams(
        storedGrams: stored,
        investedInr: invested,
        liveRatePerGram: 14000,
      );

      expect(linked, lessThan(stored));
    });

    test('current value uses stored grams times live rate', () {
      final value = MarketLinkedHoldings.currentValueInr(
        storedGrams: 0.0660,
        liveRatePerGram: 15000,
      );

      expect(value, closeTo(990, 0.01));
    });
  });
}
