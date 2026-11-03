import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/validators.dart';
import '../application/auth_providers.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _loading = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _phoneFocusNode.hasFocus);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final phone = _phoneController.text.trim();
      await ref.read(authControllerProvider.notifier).sendOtp(phone);
      if (!mounted) return;
      context.push('/auth/otp', extra: phone);
    } catch (error) {
      if (mounted) SnackbarUtils.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D1B2A);
    const cardBgColor = Color(0xFF112233);
    const borderColor = Color(0xFF1E2D3D);
    const tealColor = Color(0xFFFA0272);
    const textSecondary = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
         // physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // --- HEADER TEXT MATCHING REFERENCE DESIGN ---
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Welcome to\n',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      TextSpan(
                        text: 'AZANTO ',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: tealColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextSpan(
                        text: 'User',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Login / Register to continue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 38),

                // --- MOBILE NUMBER INPUT CARD ---
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isFocused ? tealColor : borderColor,
                      width: _isFocused ? 1.8 : 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.call_outlined,
                        color: textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          focusNode: _phoneFocusNode,
                          keyboardType: TextInputType.phone,
                          validator: Validators.phone,
                          cursorColor: tealColor,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Enter Mobile Number',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: textSecondary,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- CONTINUE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tealColor,
                      foregroundColor: const Color(0xFF0D1B2A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Color(0xFF0D1B2A),
                              strokeWidth: 2.4,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0D1B2A),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 36),

                // --- BOTTOM FOOTER TEXT ---
                Center(
                  child: GestureDetector(
                    onTap: () => _submit(),
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: 'Register',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: tealColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
