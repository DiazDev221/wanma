/// Type d'un mouvement de stock.
enum MovementType {
  inbound('IN', 'Entrée'),
  outbound('OUT', 'Sortie');

  const MovementType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static MovementType fromDb(String value) {
    return MovementType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => throw FormatException('Type de mouvement inconnu : $value'),
    );
  }
}

/// Statut d'un mouvement. Une annulation ne supprime jamais la ligne.
enum MovementStatus {
  active('ACTIVE', 'Validée'),
  cancelled('CANCELLED', 'Annulée');

  const MovementStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static MovementStatus fromDb(String value) {
    return MovementStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => throw FormatException('Statut inconnu : $value'),
    );
  }
}

/// Règlement d'une sortie de stock.
///
/// Une sortie est payée immédiatement ou à crédit. Le passage à « Payé »
/// intervient lorsque le client rembourse sa dette.
enum PaymentStatus {
  paid('PAID', 'Payé'),
  credit('CREDIT', 'À crédit');

  const PaymentStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static PaymentStatus fromDb(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => throw FormatException('Paiement inconnu : $value'),
    );
  }
}

/// Mouvement d'entrée ou de sortie, enrichi des informations produit/client
/// lorsqu'il est lu depuis la base de données.
class StockMovement {
  const StockMovement({
    this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.movementDate,
    required this.status,
    this.paymentStatus = PaymentStatus.paid,
    this.soldOnCredit = false,
    this.paidAt,
    this.notes,
    this.cancelledAt,
    this.cancellationReason,
    this.productName,
    this.productReference,
    this.productUnit,
    this.clientId,
    this.clientFirstName,
    this.clientLastName,
    this.clientPhone,
  });

  final int? id;
  final int productId;
  final MovementType movementType;
  final double quantity;
  final int unitPrice;
  final int totalAmount;
  final DateTime movementDate;
  final MovementStatus status;
  final PaymentStatus paymentStatus;

  /// Vrai si la sortie a été vendue à crédit, même après son règlement.
  final bool soldOnCredit;

  /// Date du remboursement. Reste nulle pour une sortie à crédit non réglée.
  final DateTime? paidAt;
  final String? notes;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  // Champs joints, utiles pour l'historique, les exports et les écrans.
  final String? productName;
  final String? productReference;
  final String? productUnit;
  final int? clientId;
  final String? clientFirstName;
  final String? clientLastName;
  final String? clientPhone;

  bool get isEntry => movementType == MovementType.inbound;
  bool get isExit => movementType == MovementType.outbound;
  bool get isCancelled => status == MovementStatus.cancelled;
  bool get isActive => status == MovementStatus.active;
  bool get isPaid => paymentStatus == PaymentStatus.paid;

  /// Vrai si la sortie a été vendue à crédit (réglée ou non).
  bool get isCreditSale => soldOnCredit;

  /// Vrai tant que le paiement d'une sortie à crédit est en attente.
  bool get isCredit => paymentStatus == PaymentStatus.credit;

  /// Vrai uniquement pour une sortie à crédit encore due par le client.
  bool get isCreditPending =>
      isExit && isActive && isCreditSale && paidAt == null;

  String get clientFullName {
    final parts = <String>[
      if (clientFirstName != null && clientFirstName!.trim().isNotEmpty)
        clientFirstName!.trim(),
      if (clientLastName != null && clientLastName!.trim().isNotEmpty)
        clientLastName!.trim(),
    ];
    return parts.join(' ');
  }

  double get signedQuantity => isEntry ? quantity : -quantity;

  factory StockMovement.fromMap(Map<String, Object?> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      movementType: MovementType.fromDb(map['movement_type'] as String),
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toInt(),
      totalAmount: (map['total_amount'] as num).toInt(),
      movementDate: DateTime.parse(map['movement_date'] as String),
      status: MovementStatus.fromDb(map['status'] as String),
      paymentStatus: PaymentStatus.fromDb(
        map['payment_status'] as String? ?? PaymentStatus.paid.dbValue,
      ),
      soldOnCredit: (map['sold_on_credit'] as int? ?? 0) == 1,
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.parse(map['paid_at'] as String),
      notes: map['notes'] as String?,
      cancelledAt: map['cancelled_at'] == null
          ? null
          : DateTime.parse(map['cancelled_at'] as String),
      cancellationReason: map['cancellation_reason'] as String?,
      productName: map['product_name'] as String?,
      productReference: map['product_reference'] as String?,
      productUnit: map['product_unit'] as String?,
      clientId: map['client_id'] as int?,
      clientFirstName: map['client_first_name'] as String?,
      clientLastName: map['client_last_name'] as String?,
      clientPhone: map['client_phone'] as String?,
    );
  }
}
