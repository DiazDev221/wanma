import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/formatters.dart';
import '../data/models/client.dart';
import '../data/models/product.dart';
import '../data/models/report_data.dart';
import '../data/models/stock_movement.dart';

/// Génération locale des fichiers CSV, Excel et PDF. Aucun accès réseau.
class ExportService {
  const ExportService();

  Uint8List productsCsv(List<Product> products) {
    final rows = <List<dynamic>>[
      <dynamic>[
        'Référence',
        'Produit',
        'Prix unitaire (FCFA)',
        'Quantité',
        'Unité',
        'Seuil d’alerte',
        'Valeur du stock (FCFA)',
        'Date de création',
        'Dernière modification',
        'Description',
      ],
      for (final product in products)
        <dynamic>[
          product.reference ?? '',
          product.name,
          product.unitPrice,
          product.quantity,
          product.unit,
          product.lowStockThreshold,
          product.stockValue,
          AppFormatters.dateTime(product.createdAt),
          AppFormatters.dateTime(product.updatedAt),
          product.description ?? '',
        ],
    ];
    return _csvBytes(rows);
  }

  Uint8List clientsCsv(List<Client> clients) {
    final rows = <List<dynamic>>[
      <dynamic>['Prénom', 'Nom', 'Téléphone', 'Date d’enregistrement'],
      for (final client in clients)
        <dynamic>[
          client.firstName,
          client.lastName,
          client.phone,
          AppFormatters.dateTime(client.createdAt),
        ],
    ];
    return _csvBytes(rows);
  }

  Uint8List movementsCsv(List<StockMovement> movements) {
    return _csvBytes(<List<dynamic>>[
      <dynamic>[
        'Date et heure',
        'Type',
        'Produit',
        'Référence',
        'Quantité',
        'Unité',
        'Client',
        'Téléphone',
        'Prix unitaire (FCFA)',
        'Montant total (FCFA)',
        'Statut',
        'Paiement',
        'Observation',
        'Motif d’annulation',
      ],
      for (final movement in movements)
        <dynamic>[
          AppFormatters.dateTime(movement.movementDate),
          movement.movementType.label,
          movement.productName ?? '',
          movement.productReference ?? '',
          movement.quantity,
          movement.productUnit ?? '',
          movement.isExit ? movement.clientFullName : '',
          movement.clientPhone ?? '',
          movement.unitPrice,
          movement.totalAmount,
          movement.status.label,
          movement.isExit ? movement.paymentStatus.label : '—',
          movement.notes ?? '',
          movement.cancellationReason ?? '',
        ],
    ]);
  }

  Uint8List productsExcel(List<Product> products) {
    final rows = <List<dynamic>>[
      <dynamic>[
        'Référence',
        'Produit',
        'Prix unitaire (FCFA)',
        'Quantité',
        'Unité',
        'Seuil d’alerte',
        'Valeur du stock (FCFA)',
        'Date de création',
        'Dernière modification',
        'Description',
      ],
      for (final product in products)
        <dynamic>[
          product.reference ?? '',
          product.name,
          product.unitPrice,
          product.quantity,
          product.unit,
          product.lowStockThreshold,
          product.stockValue,
          AppFormatters.dateTime(product.createdAt),
          AppFormatters.dateTime(product.updatedAt),
          product.description ?? '',
        ],
    ];
    return _excelBytes('Produits', rows);
  }

  Uint8List clientsExcel(List<Client> clients) {
    final rows = <List<dynamic>>[
      <dynamic>['Prénom', 'Nom', 'Téléphone', 'Date d’enregistrement'],
      for (final client in clients)
        <dynamic>[
          client.firstName,
          client.lastName,
          client.phone,
          AppFormatters.dateTime(client.createdAt),
        ],
    ];
    return _excelBytes('Clients', rows);
  }

  Uint8List movementsExcel(List<StockMovement> movements) {
    final rows = <List<dynamic>>[
      <dynamic>[
        'Date et heure',
        'Type',
        'Produit',
        'Référence',
        'Quantité',
        'Unité',
        'Client',
        'Téléphone',
        'Prix unitaire (FCFA)',
        'Montant total (FCFA)',
        'Statut',
        'Paiement',
        'Observation',
        'Motif d’annulation',
      ],
      for (final movement in movements)
        <dynamic>[
          AppFormatters.dateTime(movement.movementDate),
          movement.movementType.label,
          movement.productName ?? '',
          movement.productReference ?? '',
          movement.quantity,
          movement.productUnit ?? '',
          movement.isExit ? movement.clientFullName : '',
          movement.clientPhone ?? '',
          movement.unitPrice,
          movement.totalAmount,
          movement.status.label,
          movement.isExit ? movement.paymentStatus.label : '—',
          movement.notes ?? '',
          movement.cancellationReason ?? '',
        ],
    ];
    return _excelBytes('Mouvements', rows);
  }

  Uint8List reportCsv(ReportData report) {
    return movementsCsv(report.movements);
  }

  Uint8List reportExcel(ReportData report, List<Product> products) {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', 'Résumé');
    final summary = excel['Résumé'];
    final summaryRows = <List<dynamic>>[
      <dynamic>['Rapport Wanma', report.period.label],
      <dynamic>[
        'Période',
        'Du ${AppFormatters.dateTime(report.period.start)} '
            'au ${AppFormatters.dateTime(report.period.end.subtract(const Duration(seconds: 1)))}',
      ],
      <dynamic>['Entrées validées', report.activeEntries],
      <dynamic>['Sorties validées', report.activeExits],
      <dynamic>['Quantité entrée', report.entryQuantity],
      <dynamic>['Quantité sortie', report.exitQuantity],
      <dynamic>['Montant des entrées (FCFA)', report.entryAmount],
      <dynamic>['Montant des sorties (FCFA)', report.exitAmount],
      <dynamic>['Ventes à crédit (FCFA)', report.creditAmount],
      <dynamic>['Crédits non réglés (FCFA)', report.unpaidCreditAmount],
      <dynamic>['Valeur actuelle du stock (FCFA)', report.stockValue],
      <dynamic>['Opérations annulées', report.cancelledCount],
    ];
    _appendExcelRows(summary, summaryRows, headerRow: false);

    final movementsSheet = excel['Mouvements'];
    _appendExcelRows(
      movementsSheet,
      _movementRows(report.movements),
      headerRow: true,
    );

    final productsSheet = excel['Produits'];
    _appendExcelRows(productsSheet, _productRows(products), headerRow: true);

    final clientsSheet = excel['Clients'];
    _appendExcelRows(clientsSheet, <List<dynamic>>[
      <dynamic>[
        'Client',
        'Téléphone',
        'Nombre de sorties',
        'Quantité sortie',
        'Montant sorti (FCFA)',
        'Dont à crédit (FCFA)',
      ],
      for (final line in report.clientLines)
        <dynamic>[
          line.clientName,
          line.phone,
          line.movementCount,
          line.quantityOut,
          line.amountOut,
          line.creditAmount,
        ],
    ], headerRow: true);

    final bytes = excel.save(fileName: 'rapport_wanma.xlsx');
    if (bytes == null) {
      throw StateError('La génération du fichier Excel a échoué.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> reportPdf(
    ReportData report, {
    required List<Product> products,
  }) async {
    final document = pw.Document(
      title: 'Rapport Wanma - ${_pdfSafe(report.period.label)}',
      author: 'Wanma',
      creator: 'Wanma - gestion de stock hors ligne',
    );
    final blue = PdfColor.fromInt(0xFF0B55C5);
    final lightBlue = PdfColor.fromInt(0xFFE8F1FF);
    final darkText = PdfColor.fromInt(0xFF18243A);
    final dateNow = AppFormatters.dateTime(DateTime.now());

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 30),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: blue, width: 1.2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      'WANMA',
                      style: pw.TextStyle(
                        color: blue,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Votre magasin, mieux géré',
                      style: pw.TextStyle(color: darkText, fontSize: 9),
                    ),
                  ],
                ),
                pw.Text(
                  'Rapport du ${AppFormatters.date(report.period.start)}',
                  style: pw.TextStyle(color: darkText, fontSize: 9),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text(
                  'Généré le $dateNow - Données locales, hors ligne',
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber}/${context.pagesCount}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) => <pw.Widget>[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: lightBlue,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'Rapport de stock',
                  style: pw.TextStyle(
                    color: blue,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${_pdfSafe(report.period.label)}  -  '
                  'du ${AppFormatters.date(report.period.start)} '
                  'au ${AppFormatters.date(report.period.end.subtract(const Duration(days: 1)))}',
                  style: pw.TextStyle(color: darkText, fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Résumé de la période', blue),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: <String>['Indicateur', 'Valeur'],
            data: _pdfRows(<List<String>>[
              <String>['Entrées validées', '${report.activeEntries}'],
              <String>['Sorties validées', '${report.activeExits}'],
              <String>[
                'Quantité totale entrée',
                AppFormatters.quantity(report.entryQuantity),
              ],
              <String>[
                'Quantité totale sortie',
                AppFormatters.quantity(report.exitQuantity),
              ],
              <String>[
                'Montant des entrées',
                AppFormatters.money(report.entryAmount),
              ],
              <String>[
                'Montant des sorties',
                AppFormatters.money(report.exitAmount),
              ],
              <String>[
                'Ventes à crédit',
                AppFormatters.money(report.creditAmount),
              ],
              <String>[
                'Crédits non réglés',
                AppFormatters.money(report.unpaidCreditAmount),
              ],
              <String>[
                'Valeur actuelle du stock',
                AppFormatters.money(report.stockValue),
              ],
              <String>['Opérations annulées', '${report.cancelledCount}'],
            ]),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: pw.BoxDecoration(color: blue),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: <int, pw.Alignment>{1: pw.Alignment.centerRight},
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          ),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Produits les plus sortis', blue),
          if (report.topProducts.isEmpty)
            _pdfEmpty('Aucun mouvement sur cette période.')
          else
            pw.TableHelper.fromTextArray(
              headers: <String>['Produit', 'Sorti', 'Entré', 'Montant sorti'],
              data: _pdfRows(<List<String>>[
                for (final line in report.topProducts)
                  <String>[
                    line.product.name,
                    '${AppFormatters.quantity(line.quantityOut)} '
                        '${line.product.unit.toLowerCase()}',
                    '${AppFormatters.quantity(line.quantityIn)} '
                        '${line.product.unit.toLowerCase()}',
                    AppFormatters.money(line.amountOut),
                  ],
              ]),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: pw.BoxDecoration(color: blue),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
            ),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Sorties par client', blue),
          if (report.clientLines.isEmpty)
            _pdfEmpty('Aucune sortie client sur cette période.')
          else
            pw.TableHelper.fromTextArray(
              headers: <String>[
                'Client',
                'Téléphone',
                'Sorties',
                'Quantité',
                'Montant',
                'À crédit',
              ],
              data: _pdfRows(<List<String>>[
                for (final line in report.clientLines)
                  <String>[
                    line.clientName,
                    line.phone,
                    '${line.movementCount}',
                    AppFormatters.quantity(line.quantityOut),
                    AppFormatters.money(line.amountOut),
                    AppFormatters.money(line.creditAmount),
                  ],
              ]),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: pw.BoxDecoration(color: blue),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
            ),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Quantités restantes', blue),
          pw.TableHelper.fromTextArray(
            headers: <String>['Produit', 'Stock restant', 'Unité', 'Valeur'],
            data: _pdfRows(<List<String>>[
              for (final product in products)
                <String>[
                  product.name,
                  AppFormatters.quantity(product.quantity),
                  product.unit,
                  AppFormatters.money(product.stockValue),
                ],
            ]),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: pw.BoxDecoration(color: blue),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          ),
          pw.SizedBox(height: 16),
          _pdfSectionTitle('Détail des mouvements', blue),
          if (report.movements.isEmpty)
            _pdfEmpty('Aucun mouvement sur cette période.')
          else
            pw.TableHelper.fromTextArray(
              headers: <String>[
                'Date',
                'Type',
                'Produit',
                'Client',
                'Qté',
                'Montant',
                'Statut',
                'Paiement',
              ],
              data: _pdfRows(<List<String>>[
                for (final movement in report.movements)
                  <String>[
                    AppFormatters.dateTime(movement.movementDate),
                    movement.movementType.label,
                    movement.productName ?? '',
                    movement.isExit ? movement.clientFullName : '-',
                    AppFormatters.quantity(movement.quantity),
                    AppFormatters.money(movement.totalAmount),
                    movement.status.label,
                    movement.isExit ? movement.paymentStatus.label : '-',
                  ],
              ]),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              headerDecoration: pw.BoxDecoration(color: blue),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
            ),
        ],
      ),
    );
    return document.save();
  }

  Uint8List _csvBytes(List<List<dynamic>> rows) {
    final encoded = Csv(
      fieldDelimiter: ';',
      addBom: true,
      lineDelimiter: '\r\n',
    ).encode(rows);
    return Uint8List.fromList(utf8.encode(encoded));
  }

  Uint8List _excelBytes(String sheetName, List<List<dynamic>> rows) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetName);
    final sheet = excel[sheetName];
    _appendExcelRows(sheet, rows, headerRow: true);
    final bytes = excel.save(fileName: '$sheetName.xlsx');
    if (bytes == null) {
      throw StateError('La génération du fichier Excel a échoué.');
    }
    return Uint8List.fromList(bytes);
  }

  void _appendExcelRows(
    Sheet sheet,
    List<List<dynamic>> rows, {
    required bool headerRow,
  }) {
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      sheet.appendRow(
        row
            .map<CellValue?>((value) {
              if (value is int) return IntCellValue(value);
              if (value is double) return DoubleCellValue(value);
              return TextCellValue(value?.toString() ?? '');
            })
            .toList(growable: false),
      );
      if (headerRow && rowIndex == 0) {
        for (var column = 0; column < row.length; column++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
          );
          cell.cellStyle = CellStyle(
            bold: true,
            fontColorHex: ExcelColor.white,
            backgroundColorHex: ExcelColor.fromHexString('#0B55C5'),
            verticalAlign: VerticalAlign.Center,
          );
        }
      }
    }
    for (
      var column = 0;
      column < (rows.isEmpty ? 0 : rows.first.length);
      column++
    ) {
      sheet.setColumnWidth(column, 22);
    }
  }

  List<List<dynamic>> _movementRows(List<StockMovement> movements) {
    return <List<dynamic>>[
      <dynamic>[
        'Date et heure',
        'Type',
        'Produit',
        'Référence',
        'Quantité',
        'Unité',
        'Client',
        'Téléphone',
        'Prix unitaire (FCFA)',
        'Montant total (FCFA)',
        'Statut',
        'Paiement',
        'Observation',
        'Motif d’annulation',
      ],
      for (final movement in movements)
        <dynamic>[
          AppFormatters.dateTime(movement.movementDate),
          movement.movementType.label,
          movement.productName ?? '',
          movement.productReference ?? '',
          movement.quantity,
          movement.productUnit ?? '',
          movement.isExit ? movement.clientFullName : '',
          movement.clientPhone ?? '',
          movement.unitPrice,
          movement.totalAmount,
          movement.status.label,
          movement.isExit ? movement.paymentStatus.label : '—',
          movement.notes ?? '',
          movement.cancellationReason ?? '',
        ],
    ];
  }

  List<List<dynamic>> _productRows(List<Product> products) {
    return <List<dynamic>>[
      <dynamic>[
        'Référence',
        'Produit',
        'Prix unitaire (FCFA)',
        'Quantité restante',
        'Unité',
        'Valeur du stock (FCFA)',
      ],
      for (final product in products)
        <dynamic>[
          product.reference ?? '',
          product.name,
          product.unitPrice,
          product.quantity,
          product.unit,
          product.stockValue,
        ],
    ];
  }

  /// La police PDF intégrée ne couvre que le jeu Latin-1. On normalise les
  /// ponctuations typographiques françaises pour éviter les glyphes manquants,
  /// y compris dans les noms saisis par l'utilisateur.
  String _pdfSafe(String value) {
    final normalized = value
        .replaceAll('\u2019', "'")
        .replaceAll('\u2018', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2026', '...')
        .replaceAll('\u2022', '-')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ');
    return normalized.replaceAll(RegExp(r'[^\n\x20-\x7E\xA0-\xFF]'), '?');
  }

  List<List<String>> _pdfRows(List<List<String>> rows) {
    return rows
        .map((row) => row.map(_pdfSafe).toList(growable: false))
        .toList(growable: false);
  }

  pw.Widget _pdfSectionTitle(String title, PdfColor color) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _pdfEmpty(String message) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Text(
        message,
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey700,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }
}
