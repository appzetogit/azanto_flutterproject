import '../../../data/models/user_model.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../domain/model/user.dart';
import '../../domain/repository/auth_repository.dart';
import '../dto/json_reader.dart';
import '../dto/user_dto.dart';
import '../mapper/user_mapper.dart';
import 'api_paths.dart';

/// The shared Azanto account, mapped into this module's [User].
User quickUserFromShared(UserModel u) => User(
      id: u.id,
      phone: u.phone ?? '',
      name: u.name,
      email: u.email,
      profileImage: u.avatarUrl ?? '',
      countryCode: u.countryCode,
      referralCode: u.referralCode,
      gender: u.gender,
      dateOfBirth: u.dateOfBirth == null ? null : DateTime.tryParse(u.dateOfBirth!),
      isVerified: u.isVerified,
    );

/// [AuthRepository] backed by the app-wide Azanto session instead of a
/// module-private one. Identity (sign-in state, cached user, profile edits,
/// sign-out) delegates to the shared auth layer; wallet reads/top-ups go
/// straight to the backend through the shared transport.
class QuickAuthRepository implements AuthRepository {
  QuickAuthRepository(
    this._client, {
    required User? Function() cachedUserFn,
    required Future<User> Function() refreshUserFn,
    required Future<User> Function({
      String? name,
      String? email,
      String? gender,
      DateTime? dateOfBirth,
    }) updateProfileFn,
    required Future<void> Function() signOutFn,
    required Future<void> Function() deleteAccountFn,
  })  : _cachedUserFn = cachedUserFn,
        _refreshUserFn = refreshUserFn,
        _updateProfileFn = updateProfileFn,
        _signOutFn = signOutFn,
        _deleteAccountFn = deleteAccountFn;

  final ApiClient _client;
  final User? Function() _cachedUserFn;
  final Future<User> Function() _refreshUserFn;
  final Future<User> Function({
    String? name,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
  }) _updateProfileFn;
  final Future<void> Function() _signOutFn;
  final Future<void> Function() _deleteAccountFn;

  @override
  bool get isSignedIn => _cachedUserFn() != null;

  @override
  User? get cachedUser => _cachedUserFn();

  @override
  Future<OtpRequestResult> requestOtp(String phone) =>
      throw UnsupportedError('Sign-in is handled by the shared Azanto login.');

  @override
  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
    String? name,
  }) =>
      throw UnsupportedError('Sign-in is handled by the shared Azanto login.');

  @override
  Future<User> currentUser() => _refreshUserFn();

  @override
  Future<User> updateProfile({
    String? name,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
  }) =>
      _updateProfileFn(
        name: name,
        email: email,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );

  @override
  Future<Wallet> wallet() async {
    final json = await _client.get(ApiPaths.wallet, requiresAuth: true);
    if (json is! Map<String, dynamic>) return const Wallet();
    return UserMapper.walletToDomain(WalletDto.fromJson(json.mapAt('wallet')));
  }

  @override
  Future<WalletTopupOrder> createWalletTopupOrder(double amountRupees) async {
    // Backend takes rupees and mints a Razorpay order for the paise equivalent.
    final json = await _client.post(
      ApiPaths.walletTopupOrder,
      body: {'amount': amountRupees},
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) {
      throw const ParseException('Unexpected top-up response.');
    }
    final rz = json.mapAt('razorpay');
    return WalletTopupOrder(
      key: rz.str('key'),
      orderId: rz.str('orderId'),
      amountPaise: rz.integer('amount'),
      currency: rz.str('currency', 'INR'),
    );
  }

  @override
  Future<Wallet> verifyWalletTopup({
    required String orderId,
    required String paymentId,
    required String signature,
    required double amountRupees,
  }) async {
    final json = await _client.post(
      ApiPaths.walletTopupVerify,
      body: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
        // Rupees — the backend credits this exact figure after re-checking the
        // signature server-side.
        'amount': amountRupees,
      },
      requiresAuth: true,
    );
    if (json is! Map<String, dynamic>) return const Wallet();
    return UserMapper.walletToDomain(WalletDto.fromJson(json.mapAt('wallet')));
  }

  @override
  Future<void> signOut() => _signOutFn();

  @override
  Future<void> deleteAccount() => _deleteAccountFn();
}
