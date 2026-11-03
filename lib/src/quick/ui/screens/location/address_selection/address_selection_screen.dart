import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/logger.dart';
import '../../../../di/app_providers.dart';
import '../../../../di/repository_providers.dart';
import '../../../../domain/model/address.dart';
import '../../../../domain/model/place.dart';
import '../../../../domain/validator/address_validator.dart';
import '../../../../navigation/route_paths.dart';
import '../../../../platform/location/location_service.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_toast.dart';
import '../../../common/widgets/inputs/app_text_field.dart';
import '../../../common/widgets/maps/address_picker_map.dart';
import 'widgets/place_search_field.dart';

/// Add or edit a delivery address.
///
/// Used by onboarding, the address book and checkout's "Change" action.
class AddressSelectionScreen extends ConsumerStatefulWidget {
  const AddressSelectionScreen({super.key, this.existing, this.initialLocation});

  /// Non-null when editing.
  final Address? existing;

  /// Pre-filled coordinates when arriving from "use my location".
  final DeviceLocation? initialLocation;

  @override
  ConsumerState<AddressSelectionScreen> createState() =>
      _AddressSelectionScreenState();
}

class _AddressSelectionScreenState
    extends ConsumerState<AddressSelectionScreen> {
  static const _validator = AddressValidator();

  late final TextEditingController _street;
  late final TextEditingController _details;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;
  late final TextEditingController _phone;

  late AddressLabel _label;
  double? _latitude;
  double? _longitude;
  Map<String, String> _errors = const {};
  bool _saving = false;
  bool _locating = false;
  bool _resolvingPin = false;
  String _pinAddress = '';

  final _pinResolveDebouncer = Debouncer(AppDurations.pinResolveDebounce);

  /// Bumped on every accepted pin move. A resolve that returns after a newer
  /// one started is dropped, so a slow response cannot overwrite the address
  /// the user actually settled on.
  int _pinResolveSeq = 0;

  /// The last value the app itself wrote into each field. A field still
  /// holding it (or empty) follows the pin/search; once the user types their
  /// own text it is left alone.
  final Map<TextEditingController, String> _autoText = {};

  void _fill(TextEditingController c, String value, {bool force = false}) {
    final mine = c.text.trim().isEmpty || c.text == _autoText[c];
    if (!force && !mine) return;
    c.text = value;
    _autoText[c] = value;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final location = widget.initialLocation;

    _street = TextEditingController(text: existing?.street ?? '');
    _details = TextEditingController(text: existing?.additionalDetails ?? '');
    _city = TextEditingController(text: existing?.city ?? location?.city ?? '');
    _state =
        TextEditingController(text: existing?.state ?? location?.state ?? '');
    _zip =
        TextEditingController(text: existing?.zipCode ?? location?.pincode ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _label = existing?.label ?? AddressLabel.home;
    if (existing == null) {
      for (final c in [_city, _state, _zip]) {
        _autoText[c] = c.text;
      }
    }
    _latitude = existing?.latitude ?? location?.latitude;
    _longitude = existing?.longitude ?? location?.longitude;

    // Neither an existing address nor a pre-resolved location: without this,
    // the map falls back to GeolocatorLocationService.fallbackCentre (Indore)
    // no matter where the user actually is.
    if (_latitude == null && _longitude == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _useCurrentLocation();
      });
    }
  }

  @override
  void dispose() {
    _street.dispose();
    _details.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _phone.dispose();
    _pinResolveDebouncer.dispose();
    super.dispose();
  }

  Address get _address => Address(
        id: widget.existing?.id ?? '',
        label: _label,
        street: _street.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        additionalDetails: _details.text.trim(),
        zipCode: _zip.text.trim(),
        phone: _phone.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        isDefault: widget.existing?.isDefault ?? false,
      );

  /// Explicit user action: take the GPS fix as the truth and refill the form
  /// from it, overwriting anything a previous tap left behind. Fields Google
  /// has nothing for are cleared rather than left stale, so what is on screen
  /// always describes the pin — the user types the rest.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final location = await ref.read(locationServiceProvider).currentLocation();
      if (!mounted) return;

      setState(() {
        _latitude = location.latitude;
        _longitude = location.longitude;
        _pinAddress = location.formattedAddress;
        _fill(_street, location.streetLine, force: true);
        _fill(
          _details,
          location.subLocality.isNotEmpty ? location.subLocality : location.label,
          force: true,
        );
        _fill(_city, location.city, force: true);
        _fill(_state, location.state, force: true);
        _fill(_zip, location.pincode, force: true);
        _errors = {..._errors}..remove('location');
      });

      if (!location.isResolved) {
        // Two different causes, two different fixes — say which one it is
        // rather than making the user guess.
        AppToast.error(
          context,
          ref.read(appConfigProvider).hasMapsKey
              ? 'We placed the pin but could not read the address. Please fill it in.'
              : 'Address lookup is not configured in this build (MAPS_API_KEY). '
                  'Please enter the address manually.',
        );
      } else if (_street.text.trim().isEmpty) {
        AppToast.show(context, 'Add your house / flat number to finish');
      }
    } on LocationPermissionDenied catch (e) {
      if (!mounted) return;
      if (e.isPermanent) {
        AppToast.show(
          context,
          'Location is turned off for Go Azanto. Enable it in Settings.',
          actionLabel: 'SETTINGS',
          onAction: () => ref.read(permissionServiceProvider).openSettings(),
        );
      } else {
        AppToast.error(
          context,
          'Location access was denied — allow it or enter the address manually.',
        );
      }
    } on LocationUnavailable catch (e) {
      // GPS switched off, no fix within the timeout, or no last-known position.
      if (mounted) AppToast.error(context, e.message);
    } catch (e) {
      AppLogger.error('current location failed', error: e);
      if (mounted) {
        AppToast.error(context, 'Could not get your location. Try again.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Roughly 25 m in degrees at this latitude. Below this the reverse-geocoded
  /// address comes back identical — same building, same street, same pincode —
  /// so resolving it again buys nothing and costs a Geocoding call. The old
  /// gate was 0.00002° (~2 m), which let every deliberate nudge through.
  static const double _pinMoveThreshold = 0.00022;

  /// Fires when the map camera settles on a new centre.
  void _onCentreChanged(double latitude, double longitude) {
    // Ignore jitter so an idle map does not bill geocoding calls. This also
    // absorbs the idle event from a programmatic recentre — the camera lands
    // on coordinates we just set, so there is nothing to resolve.
    if (_latitude != null &&
        _longitude != null &&
        (_latitude! - latitude).abs() < _pinMoveThreshold &&
        (_longitude! - longitude).abs() < _pinMoveThreshold) {
      return;
    }

    // The pin and the spinner follow the camera immediately; only the billed
    // lookup waits. Fine-tuning a door pin is a burst of short drags, and
    // resolving each one charged for an address the user was still moving off.
    setState(() {
      _latitude = latitude;
      _longitude = longitude;
      _resolvingPin = true;
      _errors = {..._errors}..remove('location');
    });

    final seq = ++_pinResolveSeq;
    _pinResolveDebouncer.run(() => _resolvePin(latitude, longitude, seq));
  }

  Future<void> _resolvePin(double latitude, double longitude, int seq) async {
    final location =
        await ref.read(locationServiceProvider).resolve(latitude, longitude);
    if (!mounted || seq != _pinResolveSeq) return;

    setState(() {
      _resolvingPin = false;
      _pinAddress = location.formattedAddress;
      // Follow the pin, but never overwrite what the user has typed.
      _fill(_street, location.streetLine);
      _fill(_details,
          location.subLocality.isNotEmpty ? location.subLocality : location.label);
      _fill(_city, location.city);
      _fill(_state, location.state);
      _fill(_zip, location.pincode);
    });
  }

  /// Fires when a Places suggestion is chosen.
  void _onPlaceSelected(ResolvedPlace place) {
    setState(() {
      _latitude = place.latitude;
      _longitude = place.longitude;
      _pinAddress = place.formattedAddress;
      // Follow the chosen place, but never overwrite what the user typed.
      if (place.streetLine.isNotEmpty) _fill(_street, place.streetLine);
      _fill(_details, place.subLocality);
      _fill(_city, place.city);
      _fill(_state, place.state);
      // A city- or area-level result ("Udaipur, Rajasthan") has no single
      // pincode. Clear the old one rather than keep another city's, then look
      // it up from the place's coordinates.
      _fill(_zip, place.postalCode);
      _errors = {..._errors}..remove('location');
    });
    if (place.postalCode.isEmpty) _fillPincodeFrom(place.latitude, place.longitude);
  }

  Future<void> _fillPincodeFrom(double latitude, double longitude) async {
    final seq = ++_pinResolveSeq;
    try {
      final location =
          await ref.read(locationServiceProvider).resolve(latitude, longitude);
      if (!mounted || seq != _pinResolveSeq) return;
      if (location.pincode.isNotEmpty) setState(() => _fill(_zip, location.pincode));
    } catch (e) {
      AppLogger.error('pincode lookup failed', error: e);
    }
  }

  /// Manual entry produces no pin, but the backend requires coordinates on
  /// every address (zone checks, delivery distance, rider dispatch). So a
  /// fully-typed address is forward-geocoded here at save time — the map, GPS
  /// and search stay optional rather than mandatory.
  Future<bool> _geocodeTypedAddress() async {
    final query = [
      _street.text.trim(),
      _details.text.trim(),
      _city.text.trim(),
      _state.text.trim(),
      _zip.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    if (query.isEmpty) return false;

    try {
      final place = await ref.read(placeRepositoryProvider).geocodeAddress(query);
      if (place == null || !mounted) return false;
      setState(() {
        _latitude = place.latitude;
        _longitude = place.longitude;
        _pinAddress = place.formattedAddress;
      });
      return true;
    } catch (e) {
      AppLogger.error('forward geocode failed', error: e);
      return false;
    }
  }

  Future<void> _save() async {
    var errors = _validator.validate(_address);

    // No pin yet, but the rest of the form is complete — locate the typed
    // address instead of bouncing the user to the map.
    if (errors.length == 1 && errors.containsKey('location')) {
      setState(() => _saving = true);
      final located = await _geocodeTypedAddress();
      if (!mounted) return;
      setState(() => _saving = false);
      if (located) {
        errors = _validator.validate(_address);
      } else {
        AppToast.error(
          context,
          'We could not locate this address. Check the spelling and pincode, '
          'or pin it on the map.',
        );
      }
    }

    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      AppToast.error(context, errors.values.first);
      return;
    }

    setState(() => _saving = true);
    try {
      final controller = ref.read(addressBookProvider.notifier);
      if (widget.existing == null) {
        await controller.add(_address);
      } else {
        await controller.update(_address);
      }
      if (!mounted) return;

      AppToast.success(context, 'Address saved');
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(RoutePaths.home);
      }
    } catch (e, stack) {
      // Surface the real reason — "Session expired", "Latitude is required",
      // "Could not reach the server" — instead of a generic line that hides
      // whether the fix is re-login, re-pin, or retry.
      AppLogger.error('address save failed', error: e, stackTrace: stack);
      if (mounted) {
        AppToast.error(context, ErrorMapper.toFailure(e).message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The map SDK reads its own key from the manifest / Info.plist at build
  /// time, so it is not gated on the Dart-side `MAPS_API_KEY` — that one only
  /// pays for the Places REST calls.
  Widget _map(BuildContext context) {
    const centre = GeolocatorLocationService.fallbackCentre;
    return AddressPickerMap(
      latitude: _latitude ?? centre.latitude,
      longitude: _longitude ?? centre.longitude,
      isLocating: _locating,
      isResolving: _resolvingPin,
      addressLine: _pinAddress,
      onCentreChanged: _onCentreChanged,
      onUseCurrentLocation: _useCurrentLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit address' : 'Add address')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _map(context),
            const SizedBox(height: AppSpacing.md),
            PlaceSearchField(
              latitude: _latitude,
              longitude: _longitude,
              onPlaceSelected: _onPlaceSelected,
            ),
            if (_errors['location'] != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errors['location']!,
                style: context.text.bodySmall!
                    .copyWith(color: context.colors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Save as', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: AddressLabel.values
                  .map(
                    (label) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _LabelChip(
                        label: label,
                        selected: label == _label,
                        onTap: () => setState(() => _label = label),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _street,
              label: 'House / flat / block number',
              hint: 'e.g. B-402, Lakeview Residency',
              errorText: _errors['street'],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _details,
              label: 'Landmark / directions (optional)',
              hint: 'e.g. Opposite the city library',
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _city,
                    label: 'City',
                    errorText: _errors['city'],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _state,
                    label: 'State',
                    errorText: _errors['state'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _zip,
                    label: 'Pincode',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    errorText: _errors['zipCode'],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _phone,
                    label: 'Phone (optional)',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    errorText: _errors['phone'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: isEditing ? 'Update address' : 'Save address',
              isLoading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'View saved addresses',
              expand: true,
              icon: Icons.bookmark_border_rounded,
              onPressed: () => context.push(RoutePaths.addresses),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AddressLabel label;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (label) {
        AddressLabel.home => Icons.home_rounded,
        AddressLabel.office => Icons.business_rounded,
        AddressLabel.other => Icons.place_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary.withValues(alpha: 0.10)
              : context.semantic.surfaceAlt,
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: selected ? context.colors.primary : context.semantic.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 15,
              color: selected
                  ? context.colors.primary
                  : context.semantic.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label.wireValue,
              style: context.text.labelMedium!.copyWith(
                color: selected
                    ? context.colors.primary
                    : context.semantic.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
