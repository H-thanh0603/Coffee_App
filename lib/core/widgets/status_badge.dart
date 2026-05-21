import 'package:flutter/material.dart';

import '../constants/enums.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusBadge({super.key, required this.label, required this.color, this.icon});

  factory StatusBadge.order(OrderStatus s) {
    Color c;
    switch (s) {
      case OrderStatus.pending: c = AppColors.statusPending; break;
      case OrderStatus.confirmed: c = AppColors.info; break;
      case OrderStatus.preparing: c = AppColors.statusPreparing; break;
      case OrderStatus.ready: c = AppColors.statusReady; break;
      case OrderStatus.served: c = AppColors.statusServed; break;
      case OrderStatus.paid: c = AppColors.statusPaid; break;
      case OrderStatus.cancelled: c = AppColors.statusCancelled; break;
    }
    return StatusBadge(label: s.label, color: c);
  }

  factory StatusBadge.table(TableStatus s) {
    Color c;
    switch (s) {
      case TableStatus.empty: c = AppColors.tableEmpty; break;
      case TableStatus.serving: c = AppColors.tableServing; break;
      case TableStatus.waiting: c = AppColors.tableWaiting; break;
      case TableStatus.reserved: c = AppColors.tableReserved; break;
      case TableStatus.needsClean: c = AppColors.tableNeedsClean; break;
    }
    return StatusBadge(label: s.label, color: c);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
