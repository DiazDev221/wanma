import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';

/// En-tête de journée utilisé pour regrouper les opérations.
class MovementDateHeader extends StatelessWidget {
  const MovementDateHeader({
    super.key,
    required this.date,
    this.count,
    this.topPadding = 12,
  });

  final DateTime date;
  final int? count;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final label = AppFormatters.dayLabel(date);
    final countLabel = count == null
        ? null
        : '$count opération${count! > 1 ? 's' : ''}';

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 7),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 10.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (countLabel != null) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cobaltSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.cobalt,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
