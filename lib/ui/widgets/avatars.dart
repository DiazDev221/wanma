import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

/// Tuile d'initiale colorée d'un produit.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({super.key, required this.name, this.size = 46});

  final String name;
  final double size;

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFFFFF3D1), Color(0xFF9A6500)],
    <Color>[Color(0xFFDFF7EB), Color(0xFF0B7A52)],
    <Color>[Color(0xFFE9EEFF), Color(0xFF2355F2)],
    <Color>[Color(0xFFFFE7E3), Color(0xFFBE3A4A)],
    <Color>[Color(0xFFEFEAFF), Color(0xFF6D5BD0)],
    <Color>[Color(0xFFE0F4F3), Color(0xFF0E7C7B)],
  ];

  @override
  Widget build(BuildContext context) {
    final normalized = name.trim().toLowerCase();
    final palette = _palettes[normalized.hashCode.abs() % _palettes.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette[0],
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        AppFormatters.productInitials(name),
        style: TextStyle(
          color: palette[1],
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class ClientAvatar extends StatelessWidget {
  const ClientAvatar({
    super.key,
    required this.firstName,
    required this.lastName,
    this.size = 48,
  });

  final String firstName;
  final String lastName;
  final double size;

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFFE9EEFF), Color(0xFF2355F2)],
    <Color>[Color(0xFFDFF7EB), Color(0xFF0B7A52)],
    <Color>[Color(0xFFEFEAFF), Color(0xFF6D5BD0)],
    <Color>[Color(0xFFFFF3D1), Color(0xFF9A6500)],
    <Color>[Color(0xFFFFE7E3), Color(0xFFBE3A4A)],
    <Color>[Color(0xFFE0F4F3), Color(0xFF0E7C7B)],
  ];

  @override
  Widget build(BuildContext context) {
    final key = '${firstName.toLowerCase()}${lastName.toLowerCase()}';
    final palette = _palettes[key.hashCode.abs() % _palettes.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette[0],
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        AppFormatters.initials(firstName, lastName),
        style: TextStyle(
          color: palette[1],
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Pastille d'accent utilisée pour les couleurs métier.
class Dot extends StatelessWidget {
  const Dot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
