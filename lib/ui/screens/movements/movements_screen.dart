import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/movement_grouping.dart';
import '../../../data/models/stock_movement.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/movement_date_header.dart';
import '../../widgets/movement_tile.dart';
import 'movement_detail_screen.dart';

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  MovementType? _type;
  bool _creditOnly = false;
  _MovementFilters _filters = const _MovementFilters();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_filters.productId != null) count++;
    if (_filters.clientId != null) count++;
    if (_filters.from != null || _filters.to != null) count++;
    if (!_filters.includeCancelled) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _type = null;
      _creditOnly = false;
      _filters = const _MovementFilters();
    });
  }

  Future<void> _openFilters() async {
    final appState = context.read<AppState>();
    final result = await showModalBottomSheet<_MovementFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AdvancedFiltersSheet(
        initial: _filters,
        products: appState.products,
        clients: appState.clients,
      ),
    );
    if (result != null && mounted) {
      setState(() => _filters = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final movements = appState.filterMovements(
      query: _query,
      type: _type,
      unpaidCreditOnly: _creditOnly,
      productId: _filters.productId,
      clientId: _filters.clientId,
      from: _filters.from,
      to: _filters.to,
      includeCancelled: _filters.includeCancelled,
    );
    final dayGroups = groupMovementsByDay(movements);
    final productLabel = _filters.productId == null
        ? null
        : appState.productById(_filters.productId!)?.name;
    final clientLabel = _filters.clientId == null
        ? null
        : appState.clientById(_filters.clientId!)?.fullName;

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
                  const Text(
                    'Historique',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          'Mouvements',
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
                          '${appState.movements.length}',
                          style: const TextStyle(
                            color: AppColors.cobalt,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Toutes vos entrées et sorties.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  AppSearchField(
                    controller: _searchController,
                    hintText: 'Rechercher une opération...',
                    onChanged: (value) => setState(() => _query = value),
                    trailing: _MovementFilterButton(
                      count: _activeFilterCount,
                      onTap: _openFilters,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.screenPadding,
                12,
                AppTokens.screenPadding,
                4,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          _TypeChip(
                            label: 'Tout',
                            selected: _type == null && !_creditOnly,
                            onTap: () => setState(() {
                              _type = null;
                              _creditOnly = false;
                            }),
                          ),
                          const SizedBox(width: 7),
                          _TypeChip(
                            label: 'Entrées',
                            icon: Icons.arrow_downward_rounded,
                            color: AppColors.mint,
                            selected: _type == MovementType.inbound,
                            onTap: () => setState(() {
                              _type = MovementType.inbound;
                              _creditOnly = false;
                            }),
                          ),
                          const SizedBox(width: 7),
                          _TypeChip(
                            label: 'Sorties',
                            icon: Icons.arrow_upward_rounded,
                            color: AppColors.coral,
                            selected:
                                _type == MovementType.outbound && !_creditOnly,
                            onTap: () => setState(() {
                              _type = MovementType.outbound;
                              _creditOnly = false;
                            }),
                          ),
                          const SizedBox(width: 7),
                          _TypeChip(
                            label: 'Crédits',
                            icon: Icons.schedule_rounded,
                            color: AppColors.amberDark,
                            selected: _creditOnly,
                            onTap: () => setState(() {
                              _type = MovementType.outbound;
                              _creditOnly = true;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${movements.length} opération'
                    '${movements.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 9.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (productLabel != null ||
                clientLabel != null ||
                _filters.periodLabel != null ||
                !_filters.includeCancelled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            if (productLabel != null)
                              _AppliedFilter(
                                label: productLabel,
                                onDeleted: () {
                                  setState(() {
                                    _filters = _filters.copyWith(
                                      clearProduct: true,
                                    );
                                  });
                                },
                              ),
                            if (clientLabel != null)
                              _AppliedFilter(
                                label: clientLabel,
                                onDeleted: () {
                                  setState(() {
                                    _filters = _filters.copyWith(
                                      clearClient: true,
                                    );
                                  });
                                },
                              ),
                            if (_filters.periodLabel != null)
                              _AppliedFilter(
                                label: _filters.periodLabel!,
                                onDeleted: () {
                                  setState(() {
                                    _filters = _filters.copyWith(
                                      clearPeriod: true,
                                    );
                                  });
                                },
                              ),
                            if (!_filters.includeCancelled)
                              _AppliedFilter(
                                label: 'Annulées masquées',
                                onDeleted: () {
                                  setState(() {
                                    _filters = _filters.copyWith(
                                      includeCancelled: true,
                                    );
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _resetFilters,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: const Text(
                        'Effacer',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: appState.refreshData,
                child: movements.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.5,
                            child: EmptyState(
                              icon: _creditOnly
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.swap_vert_rounded,
                              title: _creditOnly
                                  ? 'Aucun crédit à recouvrer'
                                  : 'Aucun mouvement trouvé',
                              message: _creditOnly
                                  ? 'Toutes les sorties à crédit ont été remboursées.'
                                  : appState.movements.isEmpty
                                  ? 'Les entrées et sorties apparaîtront ici dès qu’elles seront enregistrées.'
                                  : 'Aucun mouvement ne correspond à votre recherche ou à vos filtres.',
                              actionLabel:
                                  (queryHasValue(_query) ||
                                      _type != null ||
                                      _creditOnly ||
                                      _activeFilterCount > 0)
                                  ? 'Effacer les filtres'
                                  : null,
                              onAction:
                                  (queryHasValue(_query) ||
                                      _type != null ||
                                      _creditOnly ||
                                      _activeFilterCount > 0)
                                  ? _resetFilters
                                  : null,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppTokens.screenPadding,
                          6,
                          AppTokens.screenPadding,
                          28,
                        ),
                        itemCount: dayGroups.length,
                        itemBuilder: (context, index) {
                          final group = dayGroups[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              MovementDateHeader(
                                date: group.date,
                                count: group.movements.length,
                                topPadding: index == 0 ? 4 : 12,
                              ),
                              for (final movement
                                  in group.movements) ...<Widget>[
                                AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 1,
                                  ),
                                  borderRadius: 16,
                                  child: MovementTile(
                                    movement: movement,
                                    onTap: () {
                                      final id = movement.id;
                                      if (id == null) return;
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MovementDetailScreen(
                                            movementId: id,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 7),
                              ],
                            ],
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

  static bool queryHasValue(String value) => value.trim().isNotEmpty;
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? null : const <BoxShadow>[AppTokens.cardShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: selected ? Colors.white : color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementFilterButton extends StatelessWidget {
  const _MovementFilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cobalt,
      borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.fieldRadius),
        child: SizedBox(
          width: 50,
          height: 51,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              const Icon(Icons.tune_rounded, color: Colors.white, size: 21),
              if (count > 0)
                Positioned(
                  right: 9,
                  top: 9,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppliedFilter extends StatelessWidget {
  const _AppliedFilter({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.only(left: 9, right: 4, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementFilters {
  const _MovementFilters({
    this.productId,
    this.clientId,
    this.from,
    this.to,
    this.periodLabel,
    this.includeCancelled = true,
  });

  final int? productId;
  final int? clientId;
  final DateTime? from;
  final DateTime? to;
  final String? periodLabel;
  final bool includeCancelled;

  bool get hasDate => from != null || to != null;

  _MovementFilters copyWith({
    int? productId,
    int? clientId,
    DateTime? from,
    DateTime? to,
    String? periodLabel,
    bool? includeCancelled,
    bool clearProduct = false,
    bool clearClient = false,
    bool clearPeriod = false,
  }) {
    return _MovementFilters(
      productId: clearProduct ? null : (productId ?? this.productId),
      clientId: clearClient ? null : (clientId ?? this.clientId),
      from: clearPeriod ? null : (from ?? this.from),
      to: clearPeriod ? null : (to ?? this.to),
      periodLabel: clearPeriod ? null : (periodLabel ?? this.periodLabel),
      includeCancelled: includeCancelled ?? this.includeCancelled,
    );
  }
}

class _AdvancedFiltersSheet extends StatefulWidget {
  const _AdvancedFiltersSheet({
    required this.initial,
    required this.products,
    required this.clients,
  });

  final _MovementFilters initial;
  final List<dynamic> products;
  final List<dynamic> clients;

  @override
  State<_AdvancedFiltersSheet> createState() => _AdvancedFiltersSheetState();
}

class _AdvancedFiltersSheetState extends State<_AdvancedFiltersSheet> {
  late int _productId;
  late int _clientId;
  late bool _includeCancelled;
  DateTime? _from;
  DateTime? _to;
  String? _periodLabel;

  @override
  void initState() {
    super.initState();
    _productId = widget.initial.productId ?? 0;
    _clientId = widget.initial.clientId ?? 0;
    _includeCancelled = widget.initial.includeCancelled;
    _from = widget.initial.from;
    _to = widget.initial.to;
    _periodLabel = widget.initial.periodLabel;
  }

  void _setPeriod(DateTime from, DateTime to, String label) {
    setState(() {
      _from = from;
      _to = to;
      _periodLabel = label;
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(
              start: _from!,
              end: _to!.subtract(const Duration(days: 1)),
            )
          : null,
      helpText: 'Filtrer par période',
      saveText: 'Appliquer',
      cancelText: 'Annuler',
    );
    if (range == null) return;
    _setPeriod(
      DateTime(range.start.year, range.start.month, range.start.day),
      DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1)),
      'Du ${AppFormatters.date(range.start)} au ${AppFormatters.date(range.end)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset * 0.1),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Filtrer l’historique',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _productId = 0;
                        _clientId = 0;
                        _from = null;
                        _to = null;
                        _periodLabel = null;
                        _includeCancelled = true;
                      });
                    },
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _productId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Produit',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem<int>(
                    value: 0,
                    child: Text('Tous les produits'),
                  ),
                  for (final product in widget.products)
                    DropdownMenuItem<int>(
                      value: product.id as int,
                      child: Text(
                        product.name as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _productId = value ?? 0),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _clientId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Client',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: <DropdownMenuItem<int>>[
                  const DropdownMenuItem<int>(
                    value: 0,
                    child: Text('Tous les clients'),
                  ),
                  for (final client in widget.clients)
                    DropdownMenuItem<int>(
                      value: client.id as int,
                      child: Text(
                        '${client.firstName} ${client.lastName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _clientId = value ?? 0),
              ),
              const SizedBox(height: 18),
              Text(
                'Période',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ActionChip(
                    avatar: const Icon(Icons.today_rounded, size: 15),
                    label: const Text('Aujourd’hui'),
                    onPressed: () {
                      final now = DateTime.now();
                      final start = DateTime(now.year, now.month, now.day);
                      _setPeriod(
                        start,
                        start.add(const Duration(days: 1)),
                        'Aujourd’hui',
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.date_range_rounded, size: 15),
                    label: const Text('7 jours'),
                    onPressed: () {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      _setPeriod(
                        today.subtract(const Duration(days: 6)),
                        today.add(const Duration(days: 1)),
                        '7 derniers jours',
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_month_rounded, size: 15),
                    label: const Text('Ce mois'),
                    onPressed: () {
                      final now = DateTime.now();
                      final start = DateTime(now.year, now.month);
                      _setPeriod(
                        start,
                        DateTime(now.year, now.month + 1),
                        'Ce mois',
                      );
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.edit_calendar_rounded, size: 15),
                    label: const Text('Période...'),
                    onPressed: _pickRange,
                  ),
                ],
              ),
              if (_periodLabel != null) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.date_range_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _periodLabel!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _from = null;
                            _to = null;
                            _periodLabel = null;
                          });
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Inclure les opérations annulées',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Les annulations restent tracées dans l’historique.',
                  style: TextStyle(fontSize: 11),
                ),
                value: _includeCancelled,
                onChanged: (value) => setState(() => _includeCancelled = value),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(
                    _MovementFilters(
                      productId: _productId == 0 ? null : _productId,
                      clientId: _clientId == 0 ? null : _clientId,
                      from: _from,
                      to: _to,
                      periodLabel: _periodLabel,
                      includeCancelled: _includeCancelled,
                    ),
                  );
                },
                icon: const Icon(Icons.filter_alt_rounded),
                label: const Text('Appliquer les filtres'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
