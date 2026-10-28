import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/client.dart';
import '../../../data/models/stock_movement.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/avatars.dart';
import '../../widgets/empty_state.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreate() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ClientFormScreen()));
  }

  void _openDetails(Client client) {
    if (client.id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientDetailScreen(clientId: client.id!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final clients = appState.searchClients(_query);
    final hasClients = appState.clients.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.screenPadding,
                12,
                AppTokens.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                'Clients',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontSize: 28),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cobaltSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${appState.clients.length}',
                                style: const TextStyle(
                                  color: AppColors.cobalt,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AddClientButton(onTap: _openCreate),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Votre répertoire, au même endroit.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  AppSearchField(
                    controller: _searchController,
                    hintText: 'Rechercher un client...',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: <Widget>[
                      const Expanded(child: MicroLabel('Tous les clients')),
                      Text(
                        'Ordre alphabétique',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 9.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: appState.refreshData,
                child: clients.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.45,
                            child: EmptyState(
                              icon: Icons.people_outline_rounded,
                              title: hasClients
                                  ? 'Aucun client trouvé'
                                  : 'Aucun client enregistré',
                              message: hasClients
                                  ? 'Essayez un nom, un prénom ou un numéro de téléphone.'
                                  : 'Ajoutez vos clients pour associer chaque sortie à la bonne personne.',
                              actionLabel: hasClients
                                  ? null
                                  : 'Ajouter un client',
                              onAction: hasClients ? null : _openCreate,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppTokens.screenPadding,
                          0,
                          AppTokens.screenPadding,
                          28,
                        ),
                        itemCount: clients.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final client = clients[index];
                          final movements = client.id == null
                              ? const <StockMovement>[]
                              : appState.movementsForClient(client.id!);
                          var total = 0;
                          for (final movement in movements) {
                            if (!movement.isCancelled) {
                              total += movement.totalAmount;
                            }
                          }
                          return _ClientListItem(
                            client: client,
                            total: total,
                            movementCount: movements.length,
                            onTap: () => _openDetails(client),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddClientButton extends StatelessWidget {
  const _AddClientButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[AppTokens.primaryShadow],
      ),
      child: Material(
        color: AppColors.cobalt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientListItem extends StatelessWidget {
  const _ClientListItem({
    required this.client,
    required this.total,
    required this.movementCount,
    required this.onTap,
  });

  final Client client;
  final int total;
  final int movementCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      borderRadius: 16,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          ClientAvatar(
            firstName: client.firstName,
            lastName: client.lastName,
            size: 42,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  client.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  client.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (total > 0)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      AppFormatters.money(total),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$movementCount sortie${movementCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              '$movementCount sortie${movementCount > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 17,
          ),
        ],
      ),
    );
  }
}
