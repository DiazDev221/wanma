import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product.dart';
import '../../data/models/stock_movement.dart';

class LowStockBadge extends StatelessWidget {
  const LowStockBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final out = product.isOutOfStock;
    final color = out ? AppColors.coral : AppColors.amberDark;
    final background = out ? AppColors.coralSoft : AppColors.amberSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        out ? 'Rupture' : 'Stock faible',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Badge du stock disponible.
class StockBadge extends StatelessWidget {
  const StockBadge({
    super.key,
    required this.quantity,
    required this.unit,
    this.lowStock = false,
  });

  final double quantity;
  final String unit;
  final bool lowStock;

  @override
  Widget build(BuildContext context) {
    final out = quantity <= 0;
    final color = out
        ? AppColors.coral
        : lowStock
        ? AppColors.amberDark
        : AppColors.mint;
    final background = out
        ? AppColors.coralSoft
        : lowStock
        ? AppColors.amberSoft
        : AppColors.mintSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        out
            ? 'Rupture'
            : '${AppFormatters.quantity(quantity)} ${unit.toLowerCase()}',
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class MovementTypeBadge extends StatelessWidget {
  const MovementTypeBadge({
    super.key,
    required this.movement,
    this.compact = false,
  });

  final StockMovement movement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final inbound = movement.isEntry;
    final color = inbound ? AppColors.mint : AppColors.coral;
    final background = inbound ? AppColors.mintSoft : AppColors.coralSoft;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            inbound ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: compact ? 11 : 13,
            color: color,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            movement.movementType.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge du règlement d'une sortie : payée ou à crédit.
class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({
    super.key,
    required this.movement,
    this.compact = false,
  });

  final StockMovement movement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final credit = movement.isCredit;
    final color = credit ? AppColors.amberDark : AppColors.mint;
    final background = credit ? AppColors.amberSoft : AppColors.mintSoft;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            credit
                ? Icons.schedule_rounded
                : Icons.check_circle_outline_rounded,
            size: compact ? 11 : 13,
            color: color,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            movement.paymentStatus.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class CancelledBadge extends StatelessWidget {
  const CancelledBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.coralSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.18)),
      ),
      child: const Text(
        'Annulée',
        style: TextStyle(
          color: AppColors.coral,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
