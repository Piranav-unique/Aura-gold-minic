import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/reports/domain/report.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/utils/file_download.dart';
import 'package:ags_gold/utils/file_download_bytes.dart';

final analyticsOverviewProvider = FutureProvider.autoDispose<AnalyticsOverview>(
  (ref) async {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.get('/reports/analytics');
    return AnalyticsOverview.fromJson(response.data as Map<String, dynamic>);
  },
);

final revenueReportProvider = FutureProvider.autoDispose<RevenueReport>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/reports/revenue');
  return RevenueReport.fromJson(response.data as Map<String, dynamic>);
});

final inventoryReportProvider = FutureProvider.autoDispose<InventoryReport>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/reports/inventory');
  return InventoryReport.fromJson(response.data as Map<String, dynamic>);
});

final customerReportProvider = FutureProvider.autoDispose<CustomerReport>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/reports/customers');
  return CustomerReport.fromJson(response.data as Map<String, dynamic>);
});

final transactionReportProvider = FutureProvider.autoDispose<TransactionReport>(
  (ref) async {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.get('/reports/transactions');
    return TransactionReport.fromJson(response.data as Map<String, dynamic>);
  },
);

final auditReportProvider = FutureProvider.autoDispose<AuditReport>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get('/reports/audit');
  return AuditReport.fromJson(response.data as Map<String, dynamic>);
});

final exportReportProvider =
    Provider<Future<void> Function(String reportType, String format)>((ref) {
      return (String reportType, String format) async {
        final apiClient = ref.read(apiClientProvider);
        final isText = format == 'csv';
        final response = await apiClient.get(
          '/reports/$reportType/export',
          queryParameters: {'format': format},
          options: Options(
            responseType: isText ? ResponseType.plain : ResponseType.bytes,
          ),
        );

        final ext = format == 'xlsx' ? 'xlsx' : format;
        final filename = 'ags_${reportType}_report.$ext';

        if (isText) {
          await downloadTextFile(
            filename: filename,
            content: response.data as String,
            mimeType: 'text/csv',
          );
        } else {
          final bytes = response.data as List<int>;
          final mime = format == 'pdf'
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          await downloadBytesFile(
            filename: filename,
            bytes: bytes,
            mimeType: mime,
          );
        }
      };
    });
