import 'package:flutter/material.dart';

import 'orders_screen.dart';

/// Azanto order history. Food only — Mart was removed, and taxi rides keep
/// their own history inside the Taxi section.
class UnifiedOrdersScreen extends StatelessWidget {
  const UnifiedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => const OrdersScreen();
}
