import 'package:flutter/material.dart';

/// Constantes générales de l'application Wanma.
abstract final class AppConstants {
  static const String appName = 'Wanma';
  static const String appTagline = 'Votre magasin, mieux géré';
  static const String currency = 'FCFA';
  static const String databaseName = 'wanma.db';
  static const int databaseVersion = 3;
  static const String backupExtension = 'wanma';
  static const String backupFormat = 'wanma-backup';
  static const int backupFormatVersion = 1;
}

/// Palette de couleurs Wanma 2.0.
///
/// L'ivoire et l'encre portent l'essentiel de l'interface. Le cobalt signale
/// l'action, l'ambre la marque et les couleurs métier racontent le mouvement :
/// menthe pour les entrées, corail pour les sorties.
abstract final class AppColors {
  // Tokens de la direction visuelle.
  static const Color ink = Color(0xFF0E1A2B);
  static const Color inkSoft = Color(0xFF22324A);
  static const Color cobalt = Color(0xFF2355F2);
  static const Color cobaltDeep = Color(0xFF153DB8);
  static const Color cobaltSoft = Color(0xFFE9EEFF);
  static const Color amber = Color(0xFFF7B733);
  static const Color amberDark = Color(0xFF9A6500);
  static const Color amberSoft = Color(0xFFFFF3D1);
  static const Color ivory = Color(0xFFF7F5F0);
  static const Color paper = Color(0xFFF0EDE6);
  static const Color line = Color(0xFFEAE6DD);
  static const Color muted = Color(0xFF646B78);
  static const Color mint = Color(0xFF0B7A52);
  static const Color mintSoft = Color(0xFFDFF7EB);
  static const Color coral = Color(0xFFBE3A4A);
  static const Color coralSoft = Color(0xFFFFE7E3);
  static const Color violet = Color(0xFF6D5BD0);
  static const Color violetSoft = Color(0xFFEFEAFF);
  static const Color teal = Color(0xFF0E7C7B);
  static const Color tealSoft = Color(0xFFE0F4F3);

  // Alias historiques conservés pour les écrans existants.
  static const Color primary = cobalt;
  static const Color primaryDark = cobaltDeep;
  static const Color primaryDeep = ink;
  static const Color primaryLight = cobaltSoft;
  static const Color accent = amber;
  static const Color background = ivory;
  static const Color surface = Colors.white;
  static const Color textPrimary = ink;
  static const Color textSecondary = muted;
  static const Color border = line;
  static const Color success = mint;
  static const Color successLight = mintSoft;
  static const Color danger = coral;
  static const Color dangerLight = coralSoft;
  static const Color warning = amberDark;
  static const Color warningLight = amberSoft;
  static const Color info = cobalt;
  static const Color infoLight = cobaltSoft;
  static const Color violetLight = violetSoft;
  static const Color tealLight = tealSoft;
}

/// Espacements, rayons et ombres partagés par les écrans.
abstract final class AppTokens {
  static const double screenPadding = 18;
  static const double sectionGap = 18;
  static const double contentMaxWidth = 640;
  static const double cardRadius = 18;
  static const double heroRadius = 22;
  static const double fieldRadius = 14;
  static const double navRadius = 21;
  static const double minTouchTarget = 48;

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x090E1A2B),
    blurRadius: 14,
    offset: Offset(0, 4),
  );

  static const BoxShadow floatingShadow = BoxShadow(
    color: Color(0x1C0E1A2B),
    blurRadius: 26,
    offset: Offset(0, 14),
  );

  static const BoxShadow primaryShadow = BoxShadow(
    color: Color(0x422355F2),
    blurRadius: 22,
    offset: Offset(0, 12),
  );
}

/// Unités de mesure proposées dans les formulaires.
const List<String> kProductUnits = <String>[
  'Pièce',
  'Carton',
  'Sac',
  'Kilogramme',
  'Litre',
  'Autre',
];

/// Options de tri de la liste des produits.
enum ProductSort {
  name('Nom (A → Z)'),
  quantityAsc('Quantité croissante'),
  quantityDesc('Quantité décroissante'),
  priceAsc('Prix croissant'),
  priceDesc('Prix décroissant'),
  recent('Ajout récent');

  const ProductSort(this.label);
  final String label;
}
