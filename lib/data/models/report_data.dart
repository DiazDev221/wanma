import 'product.dart';
import 'stock_movement.dart';

/// Période d'analyse d'un rapport.
class ReportPeriod {
  const ReportPeriod({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;

  bool contains(DateTime date) {
    return !date.isBefore(start) && date.isBefore(end);
  }
}

/// Ligne « produit le plus sorti » d'un rapport.
class ProductReportLine {
  const ProductReportLine({
    required this.product,
    required this.quantityOut,
    required this.quantityIn,
    required this.amountOut,
  });

  final Product product;
  final double quantityOut;
  final double quantityIn;
  final int amountOut;
}

/// Ligne « sorties par client » d'un rapport.
class ClientReportLine {
  const ClientReportLine({
    required this.clientId,
    required this.clientName,
    required this.phone,
    required this.movementCount,
    required this.quantityOut,
    required this.amountOut,
    required this.creditAmount,
  });

  final int clientId;
  final String clientName;
  final String phone;
  final int movementCount;
  final double quantityOut;
  final int amountOut;
  final int creditAmount;
}

/// Données agrégées d'une période.
class ReportData {
  const ReportData({
    required this.period,
    required this.movements,
    required this.activeEntries,
    required this.activeExits,
    required this.entryQuantity,
    required this.exitQuantity,
    required this.entryAmount,
    required this.exitAmount,
    required this.topProducts,
    required this.clientLines,
    required this.stockValue,
    required this.creditAmount,
    required this.unpaidCreditAmount,
  });

  final ReportPeriod period;

  /// Tous les mouvements de la période (annulés inclus).
  final List<StockMovement> movements;
  final int activeEntries;
  final int activeExits;
  final double entryQuantity;
  final double exitQuantity;
  final int entryAmount;
  final int exitAmount;
  final List<ProductReportLine> topProducts;
  final List<ClientReportLine> clientLines;
  final int stockValue;

  /// Montant des sorties vendues à crédit sur la période.
  final int creditAmount;

  /// Part de [creditAmount] encore due par les clients.
  final int unpaidCreditAmount;

  int get cancelledCount => movements.where((m) => m.isCancelled).length;
}
