import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/movement_grouping.dart';
import '../../../data/models/report_data.dart';
import '../../../services/analytics_service.dart';
import '../../../services/file_transfer_service.dart';
import '../../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/avatars.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/export_actions.dart';
import '../../widgets/movement_date_header.dart';
import '../../widgets/movement_tile.dart';
import '../movements/movement_detail_screen.dart';

enum _ReportRange { today, week, month, custom }

enum _ReportExport { csv, excel, pdf }

/// Rapports et statistiques calculés localement sur une période.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportRange _range = _ReportRange.today;
  ReportPeriod _period = AnalyticsService.periodForToday();
  _ReportExport? _exporting;

  void _selectRange(_ReportRange range) {
    if (range == _ReportRange.custom) {
      _pickCustomPeriod();
      return;
    }
    setState(() {
      _range = range;
      switch (range) {
        case _ReportRange.today:
          _period = AnalyticsService.periodForToday();
        case _ReportRange.week:
          _period = AnalyticsService.periodForWeek();
        case _ReportRange.month:
          _period = AnalyticsService.periodForMonth();
        case _ReportRange.custom:
          break;
      }
    });
  }

  Future<void> _pickCustomPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: _range == _ReportRange.custom
            ? _period.start
            : DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(const Duration(days: 6)),
        end: _range == _ReportRange.custom
            ? _period.end.subtract(const Duration(days: 1))
            : DateTime(now.year, now.month, now.day),
      ),
      helpText: 'Choisir la période du rapport',
      saveText: 'Afficher',
      cancelText: 'Annuler',
    );
    if (range == null || !mounted) return;
    setState(() {
      _range = _ReportRange.custom;
      _period = AnalyticsService.customPeriod(range.start, range.end);
    });
  }

  Future<void> _export(_ReportExport format) async {
    if (_exporting != null) return;
    final appState = context.read<AppState>();
    final report = appState.buildReport(_period);
    setState(() => _exporting = format);
    try {
      late final Uint8List bytes;
      late final String extension;
      switch (format) {
        case _ReportExport.csv:
          bytes = appState.exportService.reportCsv(report);
          extension = 'csv';
        case _ReportExport.excel:
          bytes = appState.exportService.reportExcel(report, appState.products);
          extension = 'xlsx';
        case _ReportExport.pdf:
          bytes = await appState.exportService.reportPdf(
            report,
            products: appState.products,
          );
          extension = 'pdf';
      }
      if (!mounted) return;
      await chooseExportDestination(
        context,
        bytes: bytes,
        fileName:
            'wanma_rapport_${AppFormatters.fileTimestamp(DateTime.now())}.$extension',
        mimeType: FileTransferService.mimeTypeForExtension(extension),
        title: 'Rapport prêt',
      );
    } catch (error) {
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final report = appState.buildReport(_period);
    final dayGroups = groupMovementsByDay(report.movements);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Guide des rapports',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  icon: const Icon(Icons.insights_rounded),
                  title: const Text('Comprendre les rapports'),
                  content: const Text(
                    'Les entrées et sorties validées sont comptées sur la '
                    'période choisie. Les opérations annulées restent visibles '
                    'dans le détail mais ne modifient pas les totaux. '
                    'Les ventes à crédit sont suivies séparément jusqu’au '
                    'remboursement du client. La valeur du stock utilise les '
                    'prix actuels des produits.',
                  ),
                  actions: <Widget>[
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Compris'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.help_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: appState.refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _RangeChip(
                    label: 'Aujourd’hui',
                    icon: Icons.today_rounded,
                    selected: _range == _ReportRange.today,
                    onTap: () => _selectRange(_ReportRange.today),
                  ),
                  const SizedBox(width: 8),
                  _RangeChip(
                    label: 'Semaine',
                    icon: Icons.date_range_rounded,
                    selected: _range == _ReportRange.week,
                    onTap: () => _selectRange(_ReportRange.week),
                  ),
                  const SizedBox(width: 8),
                  _RangeChip(
                    label: 'Mois',
                    icon: Icons.calendar_month_rounded,
                    selected: _range == _ReportRange.month,
                    onTap: () => _selectRange(_ReportRange.month),
                  ),
                  const SizedBox(width: 8),
                  _RangeChip(
                    label: 'Période',
                    icon: Icons.edit_calendar_rounded,
                    selected: _range == _ReportRange.custom,
                    onTap: () => _selectRange(_ReportRange.custom),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[AppColors.ink, Color(0xFF1C2C47)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTokens.heroRadius),
                boxShadow: const <BoxShadow>[AppTokens.floatingShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    report.period.label.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${report.movements.length} opération'
                          '${report.movements.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.insights_rounded,
                        color: AppColors.amber,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Du ${AppFormatters.date(report.period.start)} au '
                    '${AppFormatters.date(report.period.end.subtract(const Duration(days: 1)))}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ReportMetric(
                          label: 'Entrées validées',
                          value: '${report.activeEntries}',
                          amount: AppFormatters.money(report.entryAmount),
                          icon: Icons.arrow_downward_rounded,
                          color: const Color(0xFF8BF0C2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ReportMetric(
                          label: 'Sorties validées',
                          value: '${report.activeExits}',
                          amount: AppFormatters.money(report.exitAmount),
                          icon: Icons.arrow_upward_rounded,
                          color: const Color(0xFFFFB7B7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Valeur actuelle du stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          AppFormatters.money(report.stockValue),
                          style: const TextStyle(
                            color: AppColors.amber,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.south_rounded,
                    color: AppColors.success,
                    background: AppColors.successLight,
                    label: 'Quantité entrée',
                    value: AppFormatters.quantity(report.entryQuantity),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.north_rounded,
                    color: AppColors.danger,
                    background: AppColors.dangerLight,
                    label: 'Quantité sortie',
                    value: AppFormatters.quantity(report.exitQuantity),
                  ),
                ),
              ],
            ),
            if (report.creditAmount > 0) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.amberDark,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Ventes à crédit sur la période',
                            style: TextStyle(
                              color: AppColors.amberDark,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            report.unpaidCreditAmount > 0
                                ? '${AppFormatters.money(report.unpaidCreditAmount)} '
                                      'encore à recouvrer'
                                : 'Tous les crédits de la période sont réglés',
                            style: TextStyle(
                              color: AppColors.amberDark.withValues(
                                alpha: 0.85,
                              ),
                              fontSize: 9.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      AppFormatters.money(report.creditAmount),
                      style: const TextStyle(
                        color: AppColors.amberDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (report.cancelledCount > 0) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.amberDark,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${report.cancelledCount} opération'
                        '${report.cancelledCount > 1 ? 's annulées' : ' annulée'} '
                        'sur la période, exclue'
                        '${report.cancelledCount > 1 ? 's' : ''} des totaux.',
                        style: const TextStyle(
                          color: AppColors.amberDark,
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Produits les plus sortis',
              subtitle: 'Classement par quantité sortie sur la période.',
            ),
            if (report.topProducts.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'Aucune sortie',
                  message: 'Aucun produit n’a été sorti sur cette période.',
                  compact: true,
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < report.topProducts.length;
                      index++
                    ) ...<Widget>[
                      _ProductReportRow(
                        rank: index + 1,
                        line: report.topProducts[index],
                      ),
                      if (index < report.topProducts.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Sorties par client',
              subtitle: 'Montants validés, crédits inclus, classés par valeur.',
            ),
            if (report.clientLines.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Aucun client',
                  message: 'Aucune sortie client sur cette période.',
                  compact: true,
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < report.clientLines.length;
                      index++
                    ) ...<Widget>[
                      _ClientReportRow(line: report.clientLines[index]),
                      if (index < report.clientLines.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'Détail des opérations',
              subtitle: report.movements.isEmpty
                  ? null
                  : '${report.movements.length} opération'
                        '${report.movements.length > 1 ? 's' : ''} sur la période.',
            ),
            if (report.movements.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.swap_vert_rounded,
                  title: 'Aucun mouvement',
                  message: 'Les entrées et sorties de cette période apparaîtront ici.',
                  compact: true,
                ),
              )
            else
              for (
                var groupIndex = 0;
                groupIndex < dayGroups.length;
                groupIndex++
              ) ...<Widget>[
                MovementDateHeader(
                  date: dayGroups[groupIndex].date,
                  count: dayGroups[groupIndex].movements.length,
                  topPadding: groupIndex == 0 ? 0 : 12,
                ),
                for (final movement
                    in dayGroups[groupIndex].movements) ...<Widget>[
                  MovementTile(
                    movement: movement,
                    showAmount: true,
                    onTap: movement.id == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MovementDetailScreen(
                                  movementId: movement.id!,
                                ),
                              ),
                            );
                          },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            const SizedBox(height: 8),
            Text(
              'Exporter ce rapport',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ExportButton(
                    label: 'CSV',
                    icon: Icons.table_view_rounded,
                    color: AppColors.primary,
                    loading: _exporting == _ReportExport.csv,
                    onTap: () => _export(_ReportExport.csv),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExportButton(
                    label: 'Excel',
                    icon: Icons.grid_on_rounded,
                    color: AppColors.success,
                    loading: _exporting == _ReportExport.excel,
                    onTap: () => _export(_ReportExport.excel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExportButton(
                    label: 'PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    color: AppColors.danger,
                    loading: _exporting == _ReportExport.pdf,
                    onTap: () => _export(_ReportExport.pdf),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Le fichier est généré sur le téléphone. Vous choisissez ensuite '
              'de l’enregistrer ou de le partager.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductReportRow extends StatelessWidget {
  const _ProductReportRow({required this.rank, required this.line});

  final int rank;
  final ProductReportLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ProductAvatar(name: line.product.name, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  line.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Entré : ${AppFormatters.quantity(line.quantityIn)} · '
                  'Sorti : ${AppFormatters.quantity(line.quantityOut)} '
                  '${line.product.unit.toLowerCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${AppFormatters.quantity(line.quantityOut)} '
                '${line.product.unit.toLowerCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
              Text(
                AppFormatters.money(line.amountOut),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientReportRow extends StatelessWidget {
  const _ClientReportRow({required this.line});

  final ClientReportLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          ClientAvatar(
            firstName: line.clientName.split(' ').first,
            lastName: line.clientName.split(' ').length > 1
                ? line.clientName.split(' ').last
                : '',
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  line.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.phone} · ${line.movementCount} sortie'
                  '${line.movementCount > 1 ? 's' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                AppFormatters.money(line.amountOut),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${AppFormatters.quantity(line.quantityOut)} sorti'
                '${line.quantityOut > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (line.creditAmount > 0)
                Text(
                  'dont ${AppFormatters.money(line.creditAmount)} à crédit',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.amberDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                width: 22,
                height: 22,
                child: loading
                    ? CircularProgressIndicator(strokeWidth: 2, color: color)
                    : Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
