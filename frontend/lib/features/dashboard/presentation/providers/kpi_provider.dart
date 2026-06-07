import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/kpi.dart';

final kpiProvider = Provider<List<Kpi>>((ref) {
  return const [
    Kpi(id: 'vault', title: 'Total Gold Vault', value: '142.84 kg'),
    Kpi(id: 'users', title: 'Active Users', value: '24 Users'),
    Kpi(id: 'health', title: 'System Health', value: 'Optimal'),
  ];
});
