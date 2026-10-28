import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/stock_movement.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/badges.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_sections.dart';
import '../clients/client_detail_screen.dart';
import '../products/product_detail_screen.dart';

/// Fiche complète d'une opération de stock.
///
/// Les prix affichés sont ceux enregistrés au moment du mouvement : une
/// modification ultérieure du produit ne réécrit jamais l'historique.
class MovementDetailScreen extends StatelessWidget {
  const MovementDetailScreen({super.key, required this.movementId});

  final int movementId;

  Future<void> _cancel(BuildContext context, StockMovement movement) async {
    final appState = context.read<AppState>();
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.dangerLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.undo_rounded,
              color: AppColors.danger,
              size: 27,
            ),
          ),
          title: const Text('Annuler cette opération ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                movement.isEntry
                    ? 'La quantité entrée sera retirée du stock actuel. '
                          'L’opération restera visible dans l’historique.'
                    : 'La quantité sortie sera réintégrée au stock. '
                          'L’opération restera visible dans l’historique.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motif (optionnel)',
                  hintText: 'Ex. Erreur de saisie, retour client...',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Conserver'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Annuler l’opération'),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || !context.mounted) return;

    try {
      await appState.cancelMovement(
        movement.id!,
        reason: reason.isEmpty ? null : reason,
      );
      if (!context.mounted) return;
      AppFeedback.success(context, 'L’opération a été annulée.');
    } catch (error) {
      if (context.mounted) AppFeedback.error(context, error);
    }
  }

  Future<void> _markPaid(BuildContext context, StockMovement movement) async {
    final appState = context.read<AppState>();
    final confirmed = await AppFeedback.confirm(
      context,
      title: 'Marquer cette sortie comme payée ?',
      message:
          'Le client a remboursé ${AppFormatters.money(movement.totalAmount)}. '
          'La sortie restera dans l’historique avec le statut « Payé ».',
      confirmLabel: 'Oui, marquer payé',
      icon: Icons.check_circle_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await appState.markMovementPaid(movement.id!);
      if (!context.mounted) return;
      AppFeedback.success(context, 'La sortie est maintenant marquée payée.');
    } catch (error) {
      if (context.mounted) AppFeedback.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final movement = appState.movementById(movementId);
    if (movement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail de l’opération')),
        body: const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Opération introuvable',
          message: 'Cette opération n’existe plus dans l’historique.',
        ),
      );
    }

    final accent = movement.isCancelled
        ? AppColors.muted
        : movement.isEntry
        ? AppColors.mint
        : AppColors.coral;
    final accentBright = movement.isCancelled
        ? Colors.white70
        : movement.isEntry
        ? const Color(0xFF74E7B4)
        : const Color(0xFFFFB3B3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l’opération'),
        actions: <Widget>[
          if (movement.id != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '#${movement.id!.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.ink, Color(0xFF1C2C47)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.heroRadius),
                    boxShadow: const <BoxShadow>[AppTokens.floatingShadow],
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          movement.isEntry
                              ? Icons.south_rounded
                              : Icons.north_rounded,
                          color: accentBright,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        movement.isEntry
                            ? 'Entrée de stock'
                            : 'Sortie de stock',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.dateTime(movement.movementDate),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          MovementTypeBadge(movement: movement),
                          const SizedBox(width: 7),
                          if (movement.isCancelled)
                            const CancelledBadge()
                          else if (movement.isExit)
                            PaymentStatusBadge(movement: movement)
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Validée',
                                style: TextStyle(
                                  color: Color(0xFF74E7B4),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${movement.isEntry ? '+' : '−'}'
                        '${AppFormatters.quantity(movement.quantity)} '
                        '${(movement.productUnit ?? '').toLowerCase()}',
                        style: TextStyle(
                          color: accentBright,
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          decoration: movement.isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppFormatters.money(movement.totalAmount),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: <Widget>[
                      InfoRow(
                        label: 'Produit',
                        value: movement.productName ?? '—',
                        icon: Icons.inventory_2_outlined,
                      ),
                      InfoRow(
                        label: 'Référence',
                        value: movement.productReference?.isNotEmpty == true
                            ? movement.productReference!
                            : 'Sans référence',
                        icon: Icons.tag_rounded,
                      ),
                      InfoRow(
                        label: 'Quantité',
                        value:
                            '${AppFormatters.quantity(movement.quantity)} '
                            '${(movement.productUnit ?? '').toLowerCase()}',
                        icon: Icons.straighten_rounded,
                      ),
                      InfoRow(
                        label: 'Prix unitaire de l’opération',
                        value: AppFormatters.money(movement.unitPrice),
                        icon: Icons.payments_outlined,
                      ),
                      InfoRow(
                        label: 'Montant total',
                        value: AppFormatters.money(movement.totalAmount),
                        valueColor: accent,
                        icon: Icons.summarize_outlined,
                        isLast: !movement.isExit,
                      ),
                      if (movement.isExit && movement.clientFullName.isNotEmpty)
                        InfoRow(
                          label: 'Client',
                          value: movement.clientFullName,
                          icon: Icons.person_outline_rounded,
                        ),
                      if (movement.isExit) ...<Widget>[
                        InfoRow(
                          label: 'Paiement',
                          value: movement.isCreditSale
                              ? movement.isCreditPending
                                    ? 'À crédit · non réglé'
                                    : 'À crédit · réglé'
                              : 'Payé',
                          valueColor: movement.isCreditPending
                              ? AppColors.amberDark
                              : AppColors.mint,
                          icon: movement.isCreditPending
                              ? Icons.schedule_rounded
                              : Icons.check_circle_outline_rounded,
                          isLast: movement.paidAt == null,
                        ),
                        if (movement.paidAt != null)
                          InfoRow(
                            label: 'Réglé le',
                            value: AppFormatters.dateTime(movement.paidAt!),
                            icon: Icons.event_available_outlined,
                            isLast: true,
                          ),
                      ],
                    ],
                  ),
                ),
                if (movement.notes?.isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.notes_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Observation',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          movement.notes!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
                if (movement.isCreditPending) ...<Widget>[
                  const SizedBox(height: 14),
                  AppCard(
                    color: AppColors.amberSoft,
                    borderColor: AppColors.amber.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.schedule_rounded,
                              color: AppColors.amberDark,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Crédit à recouvrer',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: AppColors.amberDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Text(
                              AppFormatters.money(movement.totalAmount),
                              style: const TextStyle(
                                color: AppColors.amberDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Le client n’a pas encore remboursé cette sortie. '
                          'Touchez « Marquer comme payé » dès réception du '
                          'paiement.',
                          style: TextStyle(
                            color: AppColors.amberDark,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (movement.isCancelled) ...<Widget>[
                  const SizedBox(height: 14),
                  AppCard(
                    color: AppColors.dangerLight,
                    borderColor: AppColors.danger.withValues(alpha: 0.18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.cancel_outlined,
                              color: AppColors.danger,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Opération annulée',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (movement.cancelledAt != null)
                          Text(
                            'Le ${AppFormatters.dateTime(movement.cancelledAt!)}',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                            ),
                          ),
                        if (movement.cancellationReason?.isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Motif : ${movement.cancellationReason}',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          movement.isEntry
                              ? 'La quantité entrée a été retirée du stock. '
                                    'La ligne reste conservée pour la traçabilité.'
                              : 'La quantité sortie a été réintégrée au stock. '
                                    'La ligne reste conservée pour la traçabilité.',
                          style: TextStyle(
                            color: AppColors.danger.withValues(alpha: 0.82),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProductDetailScreen(
                                productId: movement.productId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: const Text('Le produit'),
                      ),
                    ),
                    if (movement.isExit && movement.clientId != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ClientDetailScreen(
                                  clientId: movement.clientId!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Le client'),
                        ),
                      ),
                    ],
                  ],
                ),
                if (movement.isCreditPending) ...<Widget>[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _markPaid(context, movement),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mint,
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Marquer comme payé'),
                  ),
                ],
                if (movement.isActive) ...<Widget>[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _cancel(context, movement),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Annuler cette opération'),
                  ),
                ],
                const SizedBox(height: 14),
                const InfoBanner(
                  text:
                      'Les prix et quantités de cette fiche sont figés au moment '
                      'de l’opération. Une modification du produit ne change pas '
                      'l’historique.',
                  icon: Icons.history_rounded,
                  color: AppColors.textSecondary,
                  backgroundColor: AppColors.background,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
