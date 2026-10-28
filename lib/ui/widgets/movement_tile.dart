import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/stock_movement.dart';
import 'badges.dart';

/// Ligne de mouvement réutilisable (accueil, historique, fiches).
///
/// La ligne est volontairement plate : elle est destinée à être regroupée
/// dans une carte unique avec des séparateurs, comme un carnet de comptes.
class MovementTile extends StatelessWidget {
  const MovementTile({
    super.key,
    required this.movement,
    this.onTap,
    this.showAmount = true,
    this.compact = false,
  });

  final StockMovement movement;
  final VoidCallback? onTap;
  final bool showAmount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isEntry = movement.isEntry;
    final color = movement.isCancelled
        ? AppColors.muted
        : isEntry
        ? AppColors.mint
        : AppColors.coral;
    final background = movement.isCancelled
        ? AppColors.paper
        : isEntry
        ? AppColors.mintSoft
        : AppColors.coralSoft;

    final title = movement.isExit && movement.clientFullName.isNotEmpty
        ? movement.clientFullName
        : movement.isEntry
        ? 'Entrée de stock'
        : (movement.productName ?? 'Sortie de stock');

    final product = movement.productName ?? '';
    final quantity = movement.productUnit == null
        ? AppFormatters.quantity(movement.quantity)
        : '${AppFormatters.quantity(movement.quantity)} '
              '${movement.productUnit!.toLowerCase()}';
    final subtitle = <String>[
      if (product.isNotEmpty && product != title) product,
      quantity,
      AppFormatters.time(movement.movementDate),
    ].join(' · ');

    final signedAmount =
        '${isEntry ? '+' : '-'}${AppFormatters.money(movement.totalAmount)}';
    final signedQuantity =
        '${isEntry ? '+' : '-'}${AppFormatters.quantity(movement.quantity)}';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 2 : 4,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEntry
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: color,
                  size: compact ? 17 : 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 12 : 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              decoration: movement.isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (movement.isCancelled) ...<Widget>[
                          const SizedBox(width: 5),
                          const CancelledBadge(),
                        ] else if (movement.isCreditPending) ...<Widget>[
                          const SizedBox(width: 5),
                          PaymentStatusBadge(movement: movement, compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        showAmount ? signedAmount : signedQuantity,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: compact ? 11.5 : 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppFormatters.time(movement.movementDate),
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
