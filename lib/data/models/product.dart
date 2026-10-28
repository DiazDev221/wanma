/// Produit stocké dans le magasin.
class Product {
  const Product({
    this.id,
    required this.name,
    this.reference,
    required this.unitPrice,
    required this.quantity,
    required this.unit,
    required this.lowStockThreshold,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final String? reference;

  /// Prix unitaire en FCFA (entier, sans centimes).
  final int unitPrice;
  final double quantity;
  final String unit;
  final double lowStockThreshold;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => quantity <= lowStockThreshold;
  bool get isOutOfStock => quantity <= 0;
  int get stockValue => (quantity * unitPrice).round();

  Product copyWith({
    int? id,
    String? name,
    String? reference,
    bool clearReference = false,
    int? unitPrice,
    double? quantity,
    String? unit,
    double? lowStockThreshold,
    String? description,
    bool clearDescription = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      reference: clearReference ? null : (reference ?? this.reference),
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      description: clearDescription ? null : (description ?? this.description),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      reference: map['reference'] as String?,
      unitPrice: (map['unit_price'] as num).toInt(),
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 5,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'name': name.trim(),
      'reference': _nullable(reference),
      'unit_price': unitPrice,
      'quantity': quantity,
      'unit': unit.trim(),
      'low_stock_threshold': lowStockThreshold,
      'description': _nullable(description),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
