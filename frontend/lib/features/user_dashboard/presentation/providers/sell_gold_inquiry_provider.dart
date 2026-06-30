import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/user_dashboard/domain/sell_gold_inquiry.dart';
import 'package:ags_gold/services/service_providers.dart';

final submitSellGoldInquiryProvider = Provider((ref) {
  return ({
    required String name,
    required String mobileNumber,
    required double quantityGrams,
    required String message,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/sell-inquiries',
      data: {
        'name': name,
        'mobile_number': mobileNumber,
        'quantity_grams': quantityGrams,
        'message': message,
      },
    );
    return SellGoldInquiry.fromJson(response.data as Map<String, dynamic>);
  };
});

final mySellGoldInquiriesProvider =
    FutureProvider.autoDispose<List<SellGoldInquiry>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/sell-inquiries/mine');
  final data = response.data as Map<String, dynamic>;
  final items = data['items'] as List<dynamic>? ?? [];
  return items
      .map((e) => SellGoldInquiry.fromJson(e as Map<String, dynamic>))
      .toList();
});
