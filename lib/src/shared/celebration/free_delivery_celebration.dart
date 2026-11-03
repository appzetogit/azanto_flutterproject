import 'package:flutter/material.dart';

/// Scopes that have already celebrated their current unlock.
///
/// Held outside any widget because the threshold is almost always crossed while
/// the shopper is still browsing — the cart they open afterwards has no
/// transition to notice, it is simply already unlocked. Cleared the moment the
/// cart drops back under, so the next crossing is a fresh win.
///
/// ponytail: in memory, so a cart left above the threshold celebrates once more
/// after an app restart. Persist it alongside the cart if that ever grates.
final Set<String> _celebrated = {};

/// Celebrates crossing the free-delivery threshold, once per unlock.
///
/// Driven from the cart screen rather than from the progress bar itself: that
/// bar sits below the fold in a lazily-built list, so on open it does not exist
/// yet and cannot announce anything. The cart always builds.
///
/// [sectionKey] is the progress bar's place in the page — the cart scrolls
/// there behind the card, so dismissing it leaves the shopper looking at the
/// unlocked bar rather than back at the top.
Future<void> celebrateFreeDeliveryUnlock(
  BuildContext context, {
  required String scope,
  required bool unlocked,
  required double threshold,
  GlobalKey? sectionKey,
}) async {
  // A shop with no offer configured is not "unlocked at zero" — it has nothing
  // to unlock, and the bar hides itself anyway.
  if (threshold <= 0) return;

  if (!unlocked) {
    _celebrated.remove(scope);
    return;
  }
  if (!_celebrated.add(scope)) return;

  // Delay ensures the section widget is mounted in the scroll view layout tree
  await Future.delayed(const Duration(milliseconds: 100));
  if (!context.mounted) return;

  final sectionContext = sectionKey?.currentContext;
  if (sectionContext == null) return;
  await Scrollable.ensureVisible(
    sectionContext,
    // A third of the way down, not hard against the top edge.
    alignment: 0.35,
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeInOutCubic,
  );
}

/// Forgets which scopes have celebrated. Tests only — each one starts from a
/// shopper who has not seen the card yet.
@visibleForTesting
void resetFreeDeliveryCelebrations() => _celebrated.clear();
