import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../services/phone_service.dart';
import 'app_feedback.dart';

/// Ouvre le composeur pour appeler un client et signale un éventuel échec.
Future<void> callClient(
  BuildContext context, {
  required String phone,
  required String clientName,
}) async {
  final launched = await PhoneService.call(phone);
  if (launched || !context.mounted) return;
  AppFeedback.error(
    context,
    const AppException(
      'Impossible d’ouvrir l’application Téléphone. Vérifiez que le numéro '
      'est valide et qu’un composeur est disponible sur cet appareil.',
    ),
  );
}

/// Numéro ou icône permettant d'appeler un client.
class ClientCallButton extends StatelessWidget {
  const ClientCallButton({
    super.key,
    required this.phone,
    required this.clientName,
    this.showNumber = false,
    this.phoneStyle,
    this.iconSize = 18,
    this.compact = false,
  });

  final String phone;
  final String clientName;

  /// Affiche le numéro à côté de l'icône au lieu d'un bouton icône seul.
  final bool showNumber;
  final TextStyle? phoneStyle;
  final double iconSize;
  final bool compact;

  Future<void> _call(BuildContext context) {
    return callClient(context, phone: phone, clientName: clientName);
  }

  @override
  Widget build(BuildContext context) {
    if (showNumber) {
      return Tooltip(
        message: 'Appeler $clientName',
        child: InkWell(
          onTap: () => _call(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: phoneStyle,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.phone_in_talk_outlined,
                  size: iconSize,
                  color: AppColors.cobalt,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: () => _call(context),
      tooltip: 'Appeler $clientName',
      icon: Icon(Icons.phone_in_talk_outlined, size: iconSize),
      color: AppColors.cobalt,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      constraints: compact
          ? const BoxConstraints(minWidth: 38, minHeight: 38)
          : null,
      padding: compact ? EdgeInsets.zero : null,
    );
  }
}
