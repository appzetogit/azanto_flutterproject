import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../application/booking_controller.dart';
import '../application/booking_state.dart';
import '../application/home_providers.dart';
import '../application/saved_places_provider.dart';
import '../data/models/saved_address_model.dart';
import 'location_access.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  /// Books from the rider's location to the saved place.
  ///
  /// With location off this used to set a pickup labelled "415, Gandhi
  /// Nagar, Bengaluru" but placed at Indore's coordinates - the screen said
  /// Bengaluru while the booking was priced and dispatched in Indore. Now it
  /// asks for location, and failing that lets the rider choose the pickup on
  /// the map.
  Future<void> _onPlaceTap(BuildContext context, WidgetRef ref, SavedAddressModel place) async {
    var position = await ref.read(currentPositionProvider.future);
    if (position == null && context.mounted) {
      final ok = await requestLocationAccess(context, ref);
      if (ok) position = await ref.read(currentPositionProvider.future);
    }
    if (!context.mounted) return;

    BookingLocation? pickupLoc;
    if (position != null) {
      final address = await ref.read(currentAddressProvider.future);
      pickupLoc = BookingLocation(
        lat: position.latitude,
        lng: position.longitude,
        address: address.isNotEmpty ? address : 'Current location',
      );
    } else {
      final picked = await context.push<Map<String, dynamic>>(
        '/home/map-picker?type=pickup',
      );
      final address = (picked?['address'] ?? '').toString();
      final lat = (picked?['lat'] as num?)?.toDouble() ?? 0;
      final lng = (picked?['lng'] as num?)?.toDouble() ?? 0;
      if (address.isNotEmpty && !(lat == 0 && lng == 0)) {
        pickupLoc = BookingLocation(lat: lat, lng: lng, address: address);
      }
    }
    if (pickupLoc == null || !context.mounted) return;

    final dropLoc = BookingLocation(
      lat: place.lat,
      lng: place.lng,
      address: place.address.isNotEmpty ? place.address : place.label,
    );

    ref.read(bookingControllerProvider.notifier)
      ..setPickup(pickupLoc)
      ..setDrop(dropLoc)
      ..goToStep(BookingStep.selectingVehicle);

    context.push('/home/ride-types');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const bgColor = Color(0xFF0D1B2A);
    const cardBgColor = Color(0xFF112233);
    const borderColor = Color(0xFF1E2D3D);
    const tealColor = Color(0xFFFA0272);
    const textSecondary = Color(0xFF94A3B8);

    final places = ref.watch(savedPlacesProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Saved Places',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddSheet(context, ref),
            icon: const Icon(Icons.add_rounded, color: tealColor, size: 20),
            label: const Text(
              'Add',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tealColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: places.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: cardBgColor,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: borderColor)),
                        ),
                        child: const Icon(
                          Icons.bookmark_border_rounded,
                          color: tealColor,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No saved places yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add your home, work, or favorite spots for faster booking.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tealColor,
                            foregroundColor: const Color(0xFF0D1B2A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _showAddSheet(context, ref),
                          child: const Text(
                            'Add a Place',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: places.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final place = places[index];
                  final isHome = place.type.toLowerCase() == 'home' || place.label.toLowerCase() == 'home';
                  final isWork = place.type.toLowerCase() == 'work' || place.label.toLowerCase() == 'work';

                  final iconData = isHome
                      ? Icons.home_rounded
                      : isWork
                          ? Icons.work_rounded
                          : Icons.bookmark_rounded;
                  final iconColor = isHome
                      ? const Color(0xFFEF4444)
                      : isWork
                          ? const Color(0xFF1E88E5)
                          : tealColor;

                  return Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      onTap: () => _onPlaceTap(context, ref, place),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1B2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(iconData, color: iconColor, size: 22),
                      ),
                      title: Text(
                        place.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: textSecondary, size: 20),
                        onPressed: () {
                          ref.read(savedPlacesProvider.notifier).remove(place.id);
                          SnackbarUtils.info(context, 'Place removed');
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: _AddPlaceForm(ref: ref),
      ),
    );
  }
}

class _AddPlaceForm extends StatefulWidget {
  final WidgetRef ref;
  const _AddPlaceForm({required this.ref});

  @override
  State<_AddPlaceForm> createState() => _AddPlaceFormState();
}

class _AddPlaceFormState extends State<_AddPlaceForm> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  String _type = 'other';
  bool _saving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cardBgColor = Color(0xFF112233);
    const borderColor = Color(0xFF1E2D3D);
    const tealColor = Color(0xFFFA0272);
    const textSecondary = Color(0xFF94A3B8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Add Saved Place',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Type Selector Chips
        Row(
          children: [
            _buildTypeChip('Home', 'home', tealColor, cardBgColor, borderColor),
            const SizedBox(width: 8),
            _buildTypeChip('Work', 'work', tealColor, cardBgColor, borderColor),
            const SizedBox(width: 8),
            _buildTypeChip('Other', 'other', tealColor, cardBgColor, borderColor),
          ],
        ),
        const SizedBox(height: 16),

        // Label Input
        const Text(
          'Label Name',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _labelController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            cursorColor: tealColor,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'e.g. My Apartment / Gym',
              hintStyle: TextStyle(color: textSecondary, fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Address Input
        const Text(
          'Address',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _addressController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            cursorColor: tealColor,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Enter full address (e.g. MG Road, Bengaluru)',
              hintStyle: TextStyle(color: textSecondary, fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Save Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tealColor,
              foregroundColor: const Color(0xFF0D1B2A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Color(0xFF0D1B2A), strokeWidth: 2.4),
                  )
                : const Text(
                    'Save Place',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTypeChip(String label, String value, Color tealColor, Color cardBgColor, Color borderColor) {
    final isSelected = _type == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = value;
          if (_labelController.text.isEmpty || _labelController.text == 'Home' || _labelController.text == 'Work') {
            _labelController.text = value == 'home' ? 'Home' : (value == 'work' ? 'Work' : '');
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5A0A2E) : cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? tealColor : borderColor, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? tealColor : Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    final address = _addressController.text.trim();
    if (label.isEmpty || address.isEmpty) {
      SnackbarUtils.info(context, 'Please enter label and address');
      return;
    }
    setState(() => _saving = true);
    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) throw Exception('Address not found');
      final loc = locations.first;
      await widget.ref.read(savedPlacesProvider.notifier).add(
            label: label,
            address: address,
            lat: loc.latitude,
            lng: loc.longitude,
            type: _type,
          );
      if (mounted) {
        Navigator.of(context).pop();
        SnackbarUtils.success(context, 'Place saved successfully!');
      }
    } catch (_) {
      if (mounted) {
        SnackbarUtils.error(context, 'Could not resolve address. Try a more specific location.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
