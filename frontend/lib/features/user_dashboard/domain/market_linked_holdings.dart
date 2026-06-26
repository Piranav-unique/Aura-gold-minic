/// Live market adjustment for savings display.
///
/// Stored grams (from purchases) are scaled by today's rate vs your average
/// buy rate so displayed grams rise when gold goes up and fall when it drops.
class MarketLinkedHoldings {
  const MarketLinkedHoldings._();

  static double marketLinkedGrams({
    required double storedGrams,
    required double investedInr,
    required double liveRatePerGram,
  }) {
    if (storedGrams <= 0 || liveRatePerGram <= 0) return storedGrams;
    if (investedInr <= 0) return storedGrams;
    final purchaseRate = investedInr / storedGrams;
    if (purchaseRate <= 0) return storedGrams;
    return storedGrams * (liveRatePerGram / purchaseRate);
  }

  static double currentValueInr({
    required double storedGrams,
    required double liveRatePerGram,
  }) {
    if (storedGrams <= 0 || liveRatePerGram <= 0) return 0;
    return storedGrams * liveRatePerGram;
  }
}
