import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ags_gold/features/profile/domain/nominee_model.dart';

const _nomineePrefsKey = 'user_nominee_details_v1';

class NomineeNotifier extends Notifier<NomineeModel> {
  bool _initialized = false;

  @override
  NomineeModel build() {
    _ensureInitialized();
    return NomineeModel.defaultNominee();
  }

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    Future.microtask(_loadPersisted);
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_nomineePrefsKey);
      if (raw != null && raw.isNotEmpty && ref.mounted) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = NomineeModel.fromJson(map);
      }
    } catch (_) {
      // Fall back to default
    }
  }

  Future<void> updateNominee(NomineeModel nominee) async {
    state = nominee;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nomineePrefsKey, jsonEncode(nominee.toJson()));
    } catch (_) {}
  }
}

final nomineeProvider = NotifierProvider<NomineeNotifier, NomineeModel>(
  NomineeNotifier.new,
);
