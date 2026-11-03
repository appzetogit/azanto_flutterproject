import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/core_providers.dart';
import '../data/models/emergency_contact_model.dart';

class EmergencyContactsNotifier extends StateNotifier<List<EmergencyContactModel>> {
  final Ref ref;
  static const _uuid = Uuid();

  EmergencyContactsNotifier(this.ref) : super([]) {
    _load();
  }

  void _load() {
    final box = ref.read(localStorageServiceProvider).emergencyContacts;
    state = box.values
        .map((e) => EmergencyContactModel.fromJson(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  Future<void> add({required String name, required String phone, String relation = 'Other'}) async {
    final box = ref.read(localStorageServiceProvider).emergencyContacts;
    final model = EmergencyContactModel(id: _uuid.v4(), name: name, phone: phone, relation: relation);
    await box.put(model.id, model.toJson());
    _load();
  }

  Future<void> remove(String id) async {
    final box = ref.read(localStorageServiceProvider).emergencyContacts;
    await box.delete(id);
    _load();
  }
}

final emergencyContactsProvider =
    StateNotifierProvider<EmergencyContactsNotifier, List<EmergencyContactModel>>((ref) {
  return EmergencyContactsNotifier(ref);
});
