import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Champ de recherche local, avec bouton d'effacement.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.trailing,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
              boxShadow: const <BoxShadow>[AppTokens.cardShadow],
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hintText,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: AppColors.muted,
                ),
                suffixIcon: controller == null
                    ? null
                    : ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller!,
                        builder: (context, value, child) {
                          if (value.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            tooltip: 'Effacer',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              controller!.clear();
                              onChanged?.call('');
                            },
                          );
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
                  borderSide: const BorderSide(
                    color: AppColors.cobalt,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 9), trailing!],
      ],
    );
  }
}
