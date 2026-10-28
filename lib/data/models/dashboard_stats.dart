import 'product.dart';
import 'stock_movement.dart';

/// Indicateurs synthétiques affichés sur le tableau de bord.
class DashboardStats {
  const DashboardStats({
    required this.productCount,
    required this.clientCount,
    required this.totalQuantity,
    required this.todayEntryCount,
    required this.todayExitCount,
    required this.stockValue,
    required this.outstandingCreditAmount,
    required this.outstandingCreditCount,
    required this.lowStockProducts,
    required this.recentMovements,
    required this.movementCount,
  });

  final int productCount;
  final int clientCount;
  final double totalQuantity;
  final int todayEntryCount;
  final int todayExitCount;
  final int stockValue;
  final int outstandingCreditAmount;
  final int outstandingCreditCount;
  final List<Product> lowStockProducts;
  final List<StockMovement> recentMovements;
  final int movementCount;
}
