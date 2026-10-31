import '../data/models/client.dart';
import '../data/models/dashboard_stats.dart';
import '../data/models/product.dart';
import '../data/models/report_data.dart';
import '../data/models/stock_movement.dart';

/// Calculs statistiques réalisés à partir des données locales chargées.
abstract final class AnalyticsService {
  static DashboardStats dashboard({
    required List<Product> products,
    required List<Client> clients,
    required List<StockMovement> movements,
    DateTime? now,
  }) {
    final today = _startOfDay(now ?? DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));

    var todayEntries = 0;
    var todayExits = 0;
    var outstandingCreditAmount = 0;
    var outstandingCreditCount = 0;
    for (final movement in movements) {
      if (!movement.isActive) continue;
      if (movement.isCreditPending) {
        outstandingCreditAmount += movement.totalAmount;
        outstandingCreditCount++;
      }
      if (movement.movementDate.isBefore(today) ||
          !movement.movementDate.isBefore(tomorrow)) {
        continue;
      }
      if (movement.isEntry) {
        todayEntries++;
      } else {
        todayExits++;
      }
    }

    final lowStock =
        products.where((product) => product.isLowStock).toList(growable: false)
          ..sort((a, b) {
            final ratioA = a.lowStockThreshold == 0
                ? (a.quantity == 0 ? 0.0 : 1.0)
                : a.quantity / a.lowStockThreshold;
            final ratioB = b.lowStockThreshold == 0
                ? (b.quantity == 0 ? 0.0 : 1.0)
                : b.quantity / b.lowStockThreshold;
            final byRatio = ratioA.compareTo(ratioB);
            return byRatio != 0
                ? byRatio
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    return DashboardStats(
      productCount: products.length,
      clientCount: clients.length,
      totalQuantity: products.fold<double>(
        0,
        (sum, product) => sum + product.quantity,
      ),
      todayEntryCount: todayEntries,
      todayExitCount: todayExits,
      stockValue: products.fold<int>(
        0,
        (sum, product) => sum + product.stockValue,
      ),
      outstandingCreditAmount: outstandingCreditAmount,
      outstandingCreditCount: outstandingCreditCount,
      lowStockProducts: lowStock,
      recentMovements: movements.take(5).toList(growable: false),
      movementCount: movements.length,
    );
  }

  /// Encaisse et crédits d'un produit sur une période donnée.
  ///
  /// Une vente comptant est comptée à sa date de sortie. Un crédit est compté
  /// à sa date de règlement, afin que le montant encaissé reflète l'argent
  /// réellement reçu. Les crédits encore dus restent visibles séparément.
  static ProductSalesStats productSalesStats({
    required int productId,
    required List<StockMovement> movements,
    required ReportPeriod period,
  }) {
    var collectedAmount = 0;
    var collectionCount = 0;
    var creditAmount = 0;
    var creditCount = 0;
    var unpaidCreditAmount = 0;
    var outstandingCreditAmount = 0;
    var outstandingCreditCount = 0;
    var saleCount = 0;

    for (final movement in movements) {
      if (!movement.isExit || movement.productId != productId) continue;

      if (movement.isCreditPending) {
        outstandingCreditAmount += movement.totalAmount;
        outstandingCreditCount++;
      }
      if (!movement.isActive) continue;

      if (period.contains(movement.movementDate)) {
        saleCount++;
        if (movement.isCreditSale) {
          creditAmount += movement.totalAmount;
          creditCount++;
          if (movement.isCreditPending) {
            unpaidCreditAmount += movement.totalAmount;
          }
        }
      }

      if (movement.isPaid) {
        final receivedAt = movement.paidAt ?? movement.movementDate;
        if (period.contains(receivedAt)) {
          collectedAmount += movement.totalAmount;
          collectionCount++;
        }
      }
    }

    return ProductSalesStats(
      period: period,
      collectedAmount: collectedAmount,
      collectionCount: collectionCount,
      creditAmount: creditAmount,
      creditCount: creditCount,
      unpaidCreditAmount: unpaidCreditAmount,
      outstandingCreditAmount: outstandingCreditAmount,
      outstandingCreditCount: outstandingCreditCount,
      saleCount: saleCount,
    );
  }

  static ReportData buildReport({
    required ReportPeriod period,
    required List<Product> products,
    required List<StockMovement> movements,
  }) {
    final periodMovements =
        movements
            .where((movement) => period.contains(movement.movementDate))
            .toList(growable: false)
          ..sort((a, b) {
            final byDate = b.movementDate.compareTo(a.movementDate);
            return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
          });

    var activeEntries = 0;
    var activeExits = 0;
    var entryQuantity = 0.0;
    var exitQuantity = 0.0;
    var entryAmount = 0;
    var exitAmount = 0;
    var creditAmount = 0;
    var unpaidCreditAmount = 0;

    final productQuantities = <int, _ProductAggregate>{};
    final clientAggregates = <int, _ClientAggregate>{};

    for (final movement in periodMovements) {
      if (!movement.isActive) continue;
      final aggregate = productQuantities.putIfAbsent(
        movement.productId,
        () => _ProductAggregate(),
      );
      if (movement.isEntry) {
        activeEntries++;
        entryQuantity += movement.quantity;
        entryAmount += movement.totalAmount;
        aggregate.quantityIn += movement.quantity;
      } else {
        activeExits++;
        exitQuantity += movement.quantity;
        exitAmount += movement.totalAmount;
        aggregate.quantityOut += movement.quantity;
        aggregate.amountOut += movement.totalAmount;
        if (movement.isCreditSale) {
          creditAmount += movement.totalAmount;
          if (movement.isCreditPending) {
            unpaidCreditAmount += movement.totalAmount;
          }
        }

        final clientId = movement.clientId;
        if (clientId != null) {
          final client = clientAggregates.putIfAbsent(
            clientId,
            () => _ClientAggregate(
              id: clientId,
              name: movement.clientFullName.isEmpty
                  ? 'Client inconnu'
                  : movement.clientFullName,
              phone: movement.clientPhone ?? '—',
            ),
          );
          client.movementCount++;
          client.quantityOut += movement.quantity;
          client.amountOut += movement.totalAmount;
          if (movement.isCreditSale) {
            client.creditAmount += movement.totalAmount;
          }
        }
      }
    }

    final productsById = <int, Product>{
      for (final product in products)
        if (product.id != null) product.id!: product,
    };

    final topProducts = <ProductReportLine>[];
    for (final entry in productQuantities.entries) {
      final product = productsById[entry.key];
      if (product == null) continue;
      if (entry.value.quantityIn == 0 && entry.value.quantityOut == 0) {
        continue;
      }
      topProducts.add(
        ProductReportLine(
          product: product,
          quantityOut: entry.value.quantityOut,
          quantityIn: entry.value.quantityIn,
          amountOut: entry.value.amountOut,
        ),
      );
    }
    topProducts.sort((a, b) {
      final byOut = b.quantityOut.compareTo(a.quantityOut);
      return byOut != 0
          ? byOut
          : a.product.name.toLowerCase().compareTo(
              b.product.name.toLowerCase(),
            );
    });

    final clientLines =
        clientAggregates.values
            .map(
              (client) => ClientReportLine(
                clientId: client.id,
                clientName: client.name,
                phone: client.phone,
                movementCount: client.movementCount,
                quantityOut: client.quantityOut,
                amountOut: client.amountOut,
                creditAmount: client.creditAmount,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.amountOut.compareTo(a.amountOut));

    return ReportData(
      period: period,
      movements: periodMovements,
      activeEntries: activeEntries,
      activeExits: activeExits,
      entryQuantity: entryQuantity,
      exitQuantity: exitQuantity,
      entryAmount: entryAmount,
      exitAmount: exitAmount,
      topProducts: topProducts,
      clientLines: clientLines,
      stockValue: products.fold<int>(
        0,
        (sum, product) => sum + product.stockValue,
      ),
      creditAmount: creditAmount,
      unpaidCreditAmount: unpaidCreditAmount,
    );
  }

  static ReportPeriod periodForToday([DateTime? now]) {
    final date = now ?? DateTime.now();
    final start = _startOfDay(date);
    return ReportPeriod(
      start: start,
      end: start.add(const Duration(days: 1)),
      label: 'Aujourd’hui',
    );
  }

  static ReportPeriod periodForWeek([DateTime? now]) {
    final date = now ?? DateTime.now();
    final start = _startOfDay(date)
        .subtract(Duration(days: date.weekday - DateTime.monday));
    return ReportPeriod(
      start: start,
      end: start.add(const Duration(days: 7)),
      label: 'Cette semaine',
    );
  }

  static ReportPeriod periodForMonth([DateTime? now]) {
    final date = now ?? DateTime.now();
    final start = DateTime(date.year, date.month);
    return ReportPeriod(
      start: start,
      end: DateTime(date.year, date.month + 1),
      label: 'Ce mois',
    );
  }

  static ReportPeriod customPeriod(DateTime startDay, DateTime endDay) {
    final start = _startOfDay(startDay);
    final endExclusive = _startOfDay(endDay).add(const Duration(days: 1));
    return ReportPeriod(
      start: start,
      end: endExclusive,
      label: 'Du ${_dateLabel(startDay)} au ${_dateLabel(endDay)}',
    );
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateLabel(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

class _ProductAggregate {
  double quantityIn = 0;
  double quantityOut = 0;
  int amountOut = 0;
}

class _ClientAggregate {
  _ClientAggregate({required this.id, required this.name, required this.phone});

  final int id;
  final String name;
  final String phone;
  int movementCount = 0;
  double quantityOut = 0;
  int amountOut = 0;
  int creditAmount = 0;
}
