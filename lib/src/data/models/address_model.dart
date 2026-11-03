class AddressModel {
  final String id;
  final String title;
  final String fullAddress;
  final String type; // 'Home', 'Office', 'Other'
  final bool isDefault;
  final String? contactName;
  final String? contactPhone;

  // Backend fields — the order payload needs the raw parts and GeoJSON, while
  // the saved-address DTO takes flat latitude/longitude. The server converts.
  final String street;

  /// Flat/floor/landmark line. Held separately rather than folded into
  /// [fullAddress] because the quick-commerce address form edits it as its own
  /// field, and both verticals share this one model.
  final String additionalDetails;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;

  /// One-line form for the home header, kept short on purpose — mirrors
  /// `quick/domain/model/address.dart`'s `shortLine`. [fullAddress] (street +
  /// details + city + state + zip) is correct in the address-picker list
  /// where the user is choosing between saved addresses and needs the whole
  /// thing to tell them apart; the home header just needs enough to confirm
  /// which address is active without crowding the row next to the avatar.
  String get shortLine {
    final detail = additionalDetails.trim();
    final streetTrimmed = street.trim();
    if (detail.isNotEmpty) return '$detail, $streetTrimmed';
    // A saved address always has a street in practice, but falling back to
    // the full string rather than an empty one means a malformed/legacy
    // address still shows something instead of masquerading as "no address".
    return streetTrimmed.isNotEmpty ? streetTrimmed : fullAddress;
  }

  const AddressModel({
    required this.id,
    required this.title,
    required this.fullAddress,
    required this.type,
    this.isDefault = false,
    this.contactName,
    this.contactPhone,
    this.street = '',
    this.additionalDetails = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.latitude,
    this.longitude,
  });

  /// Maps `GET/POST /food/user/addresses`. The response carries every
  /// coordinate representation at once (latitude/longitude, lat/lng, location).
  factory AddressModel.fromApi(Map<String, dynamic> json) {
    final parts = [
      json['street'],
      json['additionalDetails'],
      json['city'],
      json['state'],
      json['zipCode'],
    ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();

    return AddressModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['label'] ?? 'Home').toString(),
      fullAddress: parts.join(', '),
      type: (json['label'] ?? 'Home').toString(),
      isDefault: json['isDefault'] as bool? ?? false,
      contactPhone: json['phone']?.toString(),
      street: (json['street'] ?? '').toString(),
      additionalDetails: (json['additionalDetails'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zipCode: (json['zipCode'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Body for POST/PATCH /food/user/addresses (flat coordinates).
  Map<String, dynamic> toApiPayload() => {
        'label': type,
        'street': street,
        'additionalDetails': additionalDetails,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'phone': ?contactPhone,
        'latitude': ?latitude,
        'longitude': ?longitude,
      };

  /// Body for the order payload's `address` (GeoJSON `[lng, lat]`).
  Map<String, dynamic> toOrderPayload({String? customerName}) => {
        'label': type,
        'name': ?customerName,
        'street': street,
        'additionalDetails': additionalDetails,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'phone': ?contactPhone,
        if (latitude != null && longitude != null)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      };

  AddressModel copyWith({
    String? id,
    String? title,
    String? fullAddress,
    String? type,
    bool? isDefault,
    String? contactName,
    String? contactPhone,
    String? street,
    String? additionalDetails,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
  }) {
    return AddressModel(
      id: id ?? this.id,
      title: title ?? this.title,
      fullAddress: fullAddress ?? this.fullAddress,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      street: street ?? this.street,
      additionalDetails: additionalDetails ?? this.additionalDetails,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
