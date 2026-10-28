import '../../data/models/stock_movement.dart';

/// Mouvements d'une même journée, prêts à être affichés sous un en-tête.
class MovementDayGroup {
  const MovementDayGroup({required this.date, required this.movements});

  /// Journée normalisée à minuit.
  final DateTime date;
  final List<StockMovement> movements;
}

/// Regroupe les mouvements par journée, du plus récent au plus ancien.
///
/// L'ordre des mouvements d'une même journée est conservé selon la date et
/// l'identifiant décroissants, comme dans l'historique.
List<MovementDayGroup> groupMovementsByDay(Iterable<StockMovement> movements) {
  final sorted = movements.toList(growable: false)
    ..sort((a, b) {
      final byDate = b.movementDate.compareTo(a.movementDate);
      return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
    });

  final days = <DateTime>[];
  final buckets = <DateTime, List<StockMovement>>{};
  for (final movement in sorted) {
    final day = DateTime(
      movement.movementDate.year,
      movement.movementDate.month,
      movement.movementDate.day,
    );
    final bucket = buckets.putIfAbsent(day, () {
      days.add(day);
      return <StockMovement>[];
    });
    bucket.add(movement);
  }

  return <MovementDayGroup>[
    for (final day in days)
      MovementDayGroup(
        date: day,
        movements: List<StockMovement>.unmodifiable(buckets[day]!),
      ),
  ];
}
