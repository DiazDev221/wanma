import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Symbole Wanma : une boutique-entrepôt ambre sur une tuile encre.
class WanmaLogo extends StatelessWidget {
  const WanmaLogo({
    super.key,
    this.size = 52,
    // Conservé pour compatibilité : la nouvelle marque inclut sa tuile.
    this.withBackground = true,
    this.backgroundColor,
  });

  final double size;
  final bool withBackground;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo Wanma, boutique et stock',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.16),
              blurRadius: size * 0.24,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/images/wanma_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: backgroundColor ?? AppColors.ink,
            alignment: Alignment.center,
            child: Icon(
              Icons.store_rounded,
              color: AppColors.amber,
              size: size * 0.58,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nom de marque + pictogramme.
class WanmaWordmark extends StatelessWidget {
  const WanmaWordmark({
    super.key,
    this.logoSize = 36,
    this.textColor = AppColors.ink,
    this.showLogoBackground = true,
  });

  final double logoSize;
  final Color textColor;
  final bool showLogoBackground;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WanmaLogo(size: logoSize, withBackground: showLogoBackground),
        SizedBox(width: logoSize * 0.32),
        Text(
          AppConstants.appName.toUpperCase(),
          style: TextStyle(
            color: textColor,
            fontSize: logoSize * 0.42,
            fontWeight: FontWeight.w800,
            letterSpacing: logoSize * 0.04,
          ),
        ),
      ],
    );
  }
}
