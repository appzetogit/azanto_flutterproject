import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/address_model.dart';
import '../../presentation/address/viewmodels/address_viewmodel.dart';
import '../../presentation/home/viewmodels/user_location_provider.dart';
import '../../quick/core/local_storage/local_storage.dart';
import '../../quick/di/repository_providers.dart' show localStorageProvider;
import '../../quick/domain/model/address.dart' as quick;

/// The one address book for Azanto.
///
/// Addresses live on the user document, which the backend does **not** scope by
/// vertical — `/food/user/addresses` and `/quick/user/addresses` read and write
/// the same rows. So there is one list ([addressViewModelProvider]), one
/// datasource, and the selection below is global too: an address chosen while
/// ordering food is the address quick-commerce checkout starts from.
///
/// Serviceability is deliberately *not* global — each vertical still resolves
/// the delivery zone for the chosen address at order time, and either may
/// refuse it.

/// Id of the address the user is currently ordering to, persisted across
/// launches. Empty means "fall back to the default (or first) address".
class SelectedAddressNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.read(localStorageProvider).getString(StorageKeys.selectedAddressId) ??
      '';

  void select(String addressId) {
    state = addressId;
    // Picking an address is choosing it as the live one (as on Minto):
    // it becomes the default and ends "Use my current location".
    ref.read(exploringHereProvider.notifier).set(false);
    if (addressId.isNotEmpty) {
      unawaited(ref.read(addressViewModelProvider.notifier).setDefaultAddress(addressId));
    }
    ref
        .read(localStorageProvider)
        .setString(StorageKeys.selectedAddressId, addressId);
  }
}

final selectedAddressIdProvider =
    NotifierProvider<SelectedAddressNotifier, String>(
  SelectedAddressNotifier.new,
);

/// The address both verticals are delivering to — Minto's rule:
/// "Use my current location" → an unsaved "Current location" at the phone's
/// position (id '': browsing only, checkout still asks for a saved address);
/// otherwise the default saved address.
final globalSelectedAddressProvider = Provider<AddressModel?>((ref) {
  if (ref.watch(exploringHereProvider)) {
    final point = ref.watch(userLatLngProvider);
    final text = ref.watch(exploringAddressProvider).value ?? '';
    return AddressModel(
      id: '',
      title: 'Current location',
      fullAddress: text,
      type: 'Current',
      street: text.isEmpty ? 'Finding your location…' : text,
      latitude: point?.lat,
      longitude: point?.lng,
    );
  }
  ref.watch(addressViewModelProvider);
  return ref.read(addressViewModelProvider.notifier).defaultAddress;
});

/// Projections between the shared [AddressModel] and the quick-commerce
/// module's [quick.Address]. Two shapes of the same row — the quick screens and
/// its order payload were written against its own model, so it stays as a view
/// over the shared one rather than a second source of truth.
extension AddressModelToQuick on AddressModel {
  quick.Address toQuick() => quick.Address(
        id: id,
        label: quick.AddressLabel.fromWire(type),
        street: street,
        city: city,
        state: state,
        latitude: latitude,
        longitude: longitude,
        additionalDetails: additionalDetails,
        zipCode: zipCode,
        phone: contactPhone ?? '',
        isDefault: isDefault,
      );
}

extension QuickAddressToShared on quick.Address {
  AddressModel toShared() {
    final parts = [additionalDetails, street, city, state, zipCode]
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    return AddressModel(
      id: id,
      title: label.wireValue,
      fullAddress: parts.join(', '),
      type: label.wireValue,
      isDefault: isDefault,
      contactPhone: phone.isEmpty ? null : phone,
      street: street,
      additionalDetails: additionalDetails,
      city: city,
      state: state,
      zipCode: zipCode,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
