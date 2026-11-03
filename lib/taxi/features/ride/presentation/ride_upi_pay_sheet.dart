import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/razorpay_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../auth/application/auth_providers.dart';
import '../application/ride_providers.dart';
import '../application/ride_tracking_controller.dart';
import '../data/models/ride_model.dart';

/// "Pay your fare" for a cash ride, opened from the trip card - like Rapido.
///
/// The main way is Pay online: the rider pays ZI CAB through Razorpay (UPI,
/// card, wallet), the fare goes straight into the driver's ZI CAB wallet and
/// the driver's app tells them not to take cash. Under it, for a driver with a
/// verified UPI, paying them directly: their UPI ID and the fare, one tap to
/// copy each.
///
/// There is deliberately no "open my UPI app with this payment" button. A
/// `upi://pay` link to a personal UPI ID, launched from another app, is
/// declined by PhonePe and Google Pay "for security reasons" - paying to a
/// UPI ID or scanning a QR is what they allow. The driver's app shows the QR.
class RideUpiPaySheet {
  static Future<void> show(BuildContext context, RideModel ride) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _Body(ride: ride),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final RideModel ride;
  const _Body({required this.ride});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  /// The amount the server's order actually charges, once one is created.
  /// Shown from then on so the label and the success message match what the
  /// rider paid, not the possibly stale fare the sheet opened with.
  double? _orderAmount;

  RideModel get ride => widget.ride;

  String get _fareDigits {
    final f = _orderAmount ?? ride.fare;
    return f == f.roundToDouble() ? f.toInt().toString() : f.toStringAsFixed(2);
  }

  void _copy(String value, String what) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what copied')));
  }

  Future<void> _payOnline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final order = await ref.read(rideRepositoryProvider).createFareOrder(ride.rideId);
      final user = ref.read(authControllerProvider).user;

      final keyId = (order['keyId'] ?? order['key_id'] ?? '').toString();
      final orderId = (order['orderId'] ?? order['order_id'] ?? '').toString();
      // What the server charges, which can differ from the card if the fare
      // was updated a moment ago.
      final amount = double.tryParse('${order['fare'] ?? ''}') ?? ride.fare;
      if (keyId.isEmpty || orderId.isEmpty) {
        throw ApiException('Could not start the payment. Please try again.');
      }
      if (mounted) setState(() => _orderAmount = amount);

      ref.read(razorpayServiceProvider).open(
            request: RazorpayCheckoutRequest(
              keyId: keyId,
              orderId: orderId,
              // Rupees - the service converts to paise.
              amount: amount,
              name: 'ZI CAB',
              description: 'Ride fare',
              contact: user?.phone,
              email: user?.email,
            ),
            onSuccess: (PaymentSuccessResponse response) async {
              try {
                // Paid only once the server has verified it.
                await ref.read(rideRepositoryProvider).verifyFarePayment(ride.rideId, {
                  'razorpay_payment_id': response.paymentId,
                  'razorpay_order_id': response.orderId,
                  'razorpay_signature': response.signature,
                });
                await ref.read(rideTrackingControllerProvider(ride.rideId).notifier).refresh();
                if (!mounted) return;
                SnackbarUtils.success(context, 'Paid ₹$_fareDigits. Your driver has been told.');
                Navigator.of(context).pop();
              } on ApiException catch (e) {
                if (mounted) {
                  SnackbarUtils.error(context, 'Paid but not confirmed yet: ${e.message}');
                  setState(() => _busy = false);
                }
              } catch (_) {
                // Anything else (a dropped connection, a parse error) would
                // otherwise leave the spinner running with no way out.
                if (mounted) {
                  SnackbarUtils.error(context, 'Paid but not confirmed yet. Please check again shortly.');
                  setState(() => _busy = false);
                }
              }
            },
            onError: (PaymentFailureResponse response) {
              if (!mounted) return;
              SnackbarUtils.error(context, response.message ?? 'Payment failed or cancelled');
              setState(() => _busy = false);
            },
          );
    } on ApiException catch (e) {
      if (mounted) {
        SnackbarUtils.error(context, e.message);
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        SnackbarUtils.error(context, 'Could not start the payment. Please try again.');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pay = ride.driverPayment;
    final hasUpi = pay != null && pay.hasUpi;
    final payeeName = (pay?.payeeName.isNotEmpty ?? false) ? pay!.payeeName : 'your driver';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Pay your fare',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('to $payeeName',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 10),
            Text('₹$_fareDigits',
                style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _payOnline,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_rounded, size: 18),
                label: Text('Pay ₹$_fareDigits online',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'UPI, card or wallet. Goes straight to your driver.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            if (hasUpi) ...[
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or pay the driver directly',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                ],
              ),
              const SizedBox(height: 12),
              _CopyRow(label: 'UPI ID', value: pay!.upiId, onCopy: () => _copy(pay.upiId, 'UPI ID')),
              const SizedBox(height: 10),
              _CopyRow(label: 'Amount', value: '₹$_fareDigits', onCopy: () => _copy(_fareDigits, 'Amount')),
              const SizedBox(height: 10),
              const Text(
                'Scan the QR on your driver\'s phone, or in your UPI app choose "Pay to UPI ID", paste the ID and enter the amount.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Pay in cash instead', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CopyRow({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 2),
                SelectableText(value,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy', style: TextStyle(fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
