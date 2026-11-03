import 'dart:async';
import '../../home/viewmodels/user_location_provider.dart';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../data/datasources/address_remote_datasource.dart';
import '../../../data/models/address_model.dart';
import '../../../di/address_providers.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

/// Saved addresses, backed by `/food/user/addresses`.
///
/// Guests hold an empty list — the endpoint is Bearer-only — and the list
/// reloads automatically when the user logs in or out.
final addressViewModelProvider =
    NotifierProvider<AddressViewModel, List<AddressModel>>(
      AddressViewModel.new,
    );

class AddressViewModel extends Notifier<List<AddressModel>> {
  AddressRemoteDataSource get _remote =>
      ref.read(addressRemoteDataSourceProvider);

  bool isLoading = false;
  String? error;

  @override
  List<AddressModel> build() {
    // Reload whenever the session changes.
    ref.listen(authViewModelProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) {
        if (next.value == null) {
          state = const [];
        } else {
          unawaited(load());
        }
      }
    });

    if (ref.read(authViewModelProvider).value != null) {
      unawaited(load());
    }
    return const [];
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    try {
      state = await _remote.getAddresses();
    } catch (e) {
      // Keep the last-known-good list on a transient failure (e.g. a
      // timeout) instead of wiping it to empty — that previously made
      // checkout wrongly think the user had no saved address at all.
      error = _messageOf(e);
      _log('load() failed: $e');
    } finally {
      isLoading = false;
    }
  }

  /// Case- and whitespace-insensitive identity of a place, matching the
  /// server's duplicate check (which also compares the flat details this app
  /// never sends).
  static String _placeKey(AddressModel a) => [
        a.type,
        a.street,
        a.city,
        a.state,
        a.zipCode,
      ].map((v) => v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')).join('|');

  /// Saves [address] and returns the saved copy, or null on failure.
  ///
  /// [makeDefault] false keeps the customer's own selected address — for a
  /// place they are ordering to for someone else.
  Future<AddressModel?> addAddress(
    AddressModel address, {
    bool makeDefault = true,
  }) async {
    // Saving a place that is already saved used to add a second, identical row.
    // Pick the existing one instead — that is what the customer meant by it.
    final key = _placeKey(address);
    for (final existing in state) {
      if (_placeKey(existing) == key) {
        if (makeDefault) await setDefaultAddress(existing.id);
        return existing;
      }
    }

    // A new place beyond the tenth is refused; saving one already saved is
    // handled above and never counts.
    if (state.length >= maxAddresses) {
      error = 'You can save up to $maxAddresses addresses. Delete one to add another.';
      return null;
    }

    try {
      final created = await _remote.addAddress(address);
      if (!makeDefault) {
        state = [
          for (final a in state)
            if (a.id != created.id) a,
          created.copyWith(isDefault: false),
        ];
        return created;
      }
      final defaultCreated = created.copyWith(isDefault: true);
      // A newly saved delivery address is where the customer is now ordering
      // to, which ends browsing by "current location".
      ref.read(exploringHereProvider.notifier).set(false);
      // The server answers a duplicate with the address it already has, so an
      // id already in the list must replace that row rather than be appended.
      state = [
        for (final a in state)
          if (a.id != created.id) a.copyWith(isDefault: false),
        defaultCreated,
      ];
      if (created.id.isNotEmpty) {
        unawaited(setDefaultAddress(created.id));
      }
      return defaultCreated;
    } catch (e) {
      error = _messageOf(e);
      _log('addAddress() failed: $e');
      return null;
    }
  }

  Future<bool> editAddress(AddressModel address) async {
    try {
      final updated = await _remote.updateAddress(address);
      state = [for (final a in state) a.id == updated.id ? updated : a];
      return true;
    } catch (e) {
      error = _messageOf(e);
      _log('editAddress() failed: $e');
      return false;
    }
  }

  Future<bool> deleteAddress(String id) async {
    try {
      await _remote.deleteAddress(id);
      state = state.where((a) => a.id != id).toList();
      return true;
    } catch (e) {
      error = _messageOf(e);
      _log('deleteAddress() failed: $e');
      return false;
    }
  }

  Future<bool> setDefaultAddress(String id) async {
    try {
      await _remote.setDefault(id);
      // The server clears the flag on the previous default, so mirror that
      // locally instead of trusting only the returned row.
      state = [for (final a in state) a.copyWith(isDefault: a.id == id)];
      return true;
    } catch (e) {
      error = _messageOf(e);
      _log('setDefaultAddress() failed: $e');
      return false;
    }
  }

  String _messageOf(Object e) =>
      e is Failure ? e.message : 'Something went wrong. Please try again.';

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'Address');
  }

  /// Most addresses a customer may keep.
  static const maxAddresses = 10;

  AddressModel? get defaultAddress {
    for (final a in state) {
      if (a.isDefault) return a;
    }
    return state.isEmpty ? null : state.last;
  }
}
