import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/deep_link_listener.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/hero_curve_clipper.dart';
import 'profile_setup_screen.dart';
import '../../common_widgets/smart_image.dart';

class OtpScreen extends ConsumerStatefulWidget {
  /// Digits in an OTP, as the backend issues them. Public so the login screen
  /// describes the same code this screen accepts — those two drifted apart
  /// when the backend moved from 4 to 6 digits.
  static const int otpLength = 4;

  /// How long before "Resend OTP" becomes available again.
  ///
  /// One constant, for the same reason [otpLength] is one: the value lived in
  /// two places — the initial countdown and the restart — and two copies of a
  /// number are two chances to change only one of them.
  static const int resendCooldownSeconds = 60;

  final String phoneNumber;

  final String? name;

  /// A friend's code, typed at signup. Sent as `ref` on verify-otp, which the
  /// backend credits for brand-new accounts only.
  final String? referralCode;

  final String? fromPath;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.name,
    this.referralCode,
    this.fromPath,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  /// Digits in an OTP, as the backend issues them.
  ///
  /// Everything on this screen derives from this — box count, layout, the
  /// "enter the N-digit code" copy, the completeness check and the autofill
  /// distribution. It was hardcoded as 4 in eight places, so when the backend
  /// moved to 6-digit codes the screen could not accept one at all: two digits
  /// had nowhere to go, the completeness check never fired, and autofill
  /// silently dropped the overflow.
  final List<TextEditingController> _controllers =
      List.generate(OtpScreen.otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(OtpScreen.otpLength, (_) => FocusNode());

  int _resendCountdown = OtpScreen.resendCooldownSeconds;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[AUTH] OTP screen opened for +91 ${widget.phoneNumber}');
    _startResendTimer();

    _listenForSms();

    // The field starts empty. It used to be prefilled with the backend's
    // echoed OTP, falling back to a literal '1234' when there was none — so in
    // production every user was handed a wrong code that looked like a real
    // one. The `devOtp` plumbing is gone entirely rather than left dormant.

    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  /// Reads the incoming OTP SMS via the SMS **User Consent** API.
  ///
  /// Chosen over SMS Retriever because Retriever requires an 11-char app hash
  /// inside the SMS body, which would mean changing the DLT-approved template
  /// server-side. User Consent needs no such change and, critically, no
  /// SMS/phone permission — Android shows a one-tap system prompt instead, and
  /// only for a message that arrives while this screen is listening.
  ///
  /// The future completes when the SMS arrives, the user declines, or the
  /// listener is torn down; it never blocks manual entry.
  Future<void> _listenForSms() async {
    try {
      final result = await SmartAuth.instance.getSmsWithUserConsentApi(
        // Codes are 4-8 digits; anchor on the configured length first.
        matcher: '\\d{${OtpScreen.otpLength}}',
      );
      if (!mounted) return;
      final code = result.data?.code;
      if (code == null || code.isEmpty) return;
      // Reuse the same path as paste/iOS autofill so ordering and the
      // auto-submit guard behave identically however the code arrives.
      _fillFromAutofill(code);
    } catch (_) {
      // Consent declined, unsupported device, or Play Services missing —
      // manual entry is unaffected, so there is nothing to report.
    }
  }

  @override
  void dispose() {
    // Stop the listener with the screen, so returning to it starts a fresh one
    // rather than stacking a second consent prompt.
    SmartAuth.instance.removeUserConsentApiListener();
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = OtpScreen.resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  /// Spreads a full code across the four boxes.
  ///
  /// Autofill (iOS QuickType, the Android autofill service) and a clipboard
  /// paste all deliver the whole code into whichever box has focus. Writing it
  /// verbatim would leave "1234" in one box and the rest empty, so the digits
  /// are dealt out one per box from the left. Filling left-to-right — rather
  /// than from the focused index — is what keeps the order correct no matter
  /// which box the OS happened to target.
  void _fillFromAutofill(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;

    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }

    final filled = digits.length.clamp(0, _controllers.length);
    if (filled >= _controllers.length) {
      _focusNodes.last.unfocus();
      // Same guard as manual entry: never let autofill race the Verify button
      // into submitting a single-use OTP twice.
      if (_enteredOtp.length == OtpScreen.otpLength && !_isVerifying) _verifyOtp();
    } else {
      _focusNodes[filled].requestFocus();
    }
  }

  void _onOtpDigitChanged(int index, String value) {
    // More than one character means it arrived as a block, not a keystroke.
    if (value.length > 1) {
      _fillFromAutofill(value);
      return;
    }
    if (value.isNotEmpty) {
      Haptics.light();
      if (index < OtpScreen.otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Auto-submit once all four digits are in — but only if a verification
        // isn't already running, so this can't race the Verify button and
        // submit the single-use OTP twice.
        if (_enteredOtp.length == OtpScreen.otpLength && !_isVerifying) {
          _verifyOtp();
        }
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyOtp() async {
    // Re-entry guard: the button and the auto-submit path must never both fire.
    // Combined with the view model's single-flight, the OTP is submitted once.
    if (_isVerifying) return;

    final enteredOtp = _enteredOtp;
    if (enteredOtp.length < OtpScreen.otpLength) {
      _showSnackBar(
          AppSnackbarType.warning, 'Please enter the ${OtpScreen.otpLength}-digit code');
      return;
    }

    setState(() => _isVerifying = true);
    Haptics.medium();

    if (kDebugMode) debugPrint('[AUTH] OTP entered: $enteredOtp');

    final notifier = ref.read(authViewModelProvider.notifier);
    // Submit exactly what the user typed. Substituting the echoed dev OTP would
    // let any wrong code "succeed"; a real "1234" still matches the dev OTP.
    final session = await notifier.verifyOtp(
      phone: widget.phoneNumber,
      otp: enteredOtp,
      name: widget.name,
      referralCode: widget.referralCode,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (session == null) {
      // Failure path: no session was created, no auth state changed, no
      // navigation — the user stays a guest.
      _showSnackBar(AppSnackbarType.error, notifier.lastError ?? 'Invalid OTP. Please try again.');
      Haptics.error();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      return;
    }

    Haptics.success();

    // The invite has been spent -- clear it so a later signup on this device
    // (a shared phone, or a reinstall) does not resubmit somebody else's code.
    // Only on success: a failed verify must keep it for the retry.
    if (widget.referralCode != null && widget.referralCode!.isNotEmpty) {
      unawaited(DeepLinkListener.clearReferralCode());
    }

    if (kDebugMode) debugPrint('[AUTH] Login completed · redirecting');

    // OtpScreen is pushed imperatively (Navigator/MaterialPageRoute), so it is
    // NOT inside a GoRoute subtree — GoRouterState.of(context) would throw. The
    // redirect target is already threaded in via widget.fromPath.
    final target = widget.fromPath ?? RouteNames.home;

    // A brand-new account has no usable name yet — finish onboarding before
    // dropping the user into the app.
    if (session.needsProfileSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(redirectTo: target),
        ),
      );
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    context.go(target);
  }

  void _handleResendOtp() async {
    if (_resendCountdown > 0) return;
    Haptics.light();
    final result = await ref.read(authViewModelProvider.notifier).requestOtp(widget.phoneNumber);
    if (!mounted) return;
    if (!result.ok) {
      _showSnackBar(
        AppSnackbarType.error,
        ref.read(authViewModelProvider.notifier).lastError ?? 'Could not resend OTP.',
      );
      return;
    }
    _startResendTimer();
    _showSnackBar(AppSnackbarType.success, 'New OTP code sent to +91 ${widget.phoneNumber}');
  }

  void _showSnackBar(AppSnackbarType type, String msg) {
    if (!mounted) return;
    AppSnackbar.show(context, msg, type: type, duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgColor = isDark ? AppColors.backgroundDark : const Color(0xFFFAF9F6);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // Top Curved Hero Image Banner
              SizedBox(
                height: 240,
                width: double.infinity,
                child: Stack(
                  children: [
                    ClipPath(
                      clipper: HeroCurveClipper(),
                      child: Container(
                        height: 240,
                        width: double.infinity,
                        color: const Color(0xFF09121D),
                        child: const SmartImage(
                          url: 'assets/images/login_hero.webp',
                          category: ImageCategory.food,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () {
                            Haptics.light();
                            context.pop();
                          },
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Title & Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify OTP 🔒',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the ${OtpScreen.otpLength}-digit code sent to +91 ${widget.phoneNumber}',
                      style: TextStyle(fontSize: 13.5, color: secondaryColor, height: 1.3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 4 PIN Code Entry Cells
              //
              // AutofillGroup is what lets the platform treat these boxes as one
              // credential field and commit the fill; without it iOS offers the
              // code in the QuickType bar but never delivers it. It is a purely
              // structural wrapper — it paints nothing, so the layout is
              // unchanged.
              AutofillGroup(
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(OtpScreen.otpLength, (index) {
                    final isFocused = _focusNodes[index].hasFocus;
                    // Width follows the box count so six fit a 360dp screen
                    // without overflowing; the design (radius, border, focus
                    // glow, height) is untouched.
                    return Container(
                      width: OtpScreen.otpLength > 4 ? 46 : 58,
                      height: 60,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDark
                            ? (isFocused ? const Color(0xFF2E2E2E) : AppColors.cardDark)
                            : (isFocused ? Colors.white : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFocused
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : const Color(0xFFE0E0E0)),
                          width: isFocused ? 1.8 : 1.0,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryAlpha(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          // Only the first box advertises the hint: the OS
                          // delivers one whole code, and _fillFromAutofill
                          // deals it out. Declaring it on all four invites
                          // duplicate fills.
                          autofillHints: index == 0
                              ? const [AutofillHints.oneTimeCode]
                              : null,
                          // Was 1, which truncated an autofilled "1234" down to
                          // "1" before onChanged ever saw it. Each box still
                          // displays a single digit — _fillFromAutofill
                          // normalises straight away.
                          maxLength: OtpScreen.otpLength,
                          cursorColor: AppColors.primary,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            counterText: '',
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) => _onOtpDigitChanged(index, val),
                        ),
                      ),
                    );
                  }),
                ),
                ),
              ),

              const SizedBox(height: 32),

              // Verify Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: _isVerifying ? null : _verifyOtp,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Verify & Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend OTP Countdown & Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Didn\'t receive OTP? ',
                    style: TextStyle(fontSize: 13.5, color: secondaryColor),
                  ),
                  if (_resendCountdown > 0)
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _handleResendOtp,
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
