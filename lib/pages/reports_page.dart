import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';
import '../database.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _compartmentStats = [];
  List<Map<String, dynamic>> _recentActivity = [];

  // Filtres de date
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      String dateFilter = '';
      List<dynamic> dateArgs = [];

      if (_startDate != null && _endDate != null) {
        dateFilter = ' WHERE d.added_at BETWEEN ? AND ?';
        dateArgs = [
          _startDate?.toIso8601String() ?? '',
          _endDate?.add(const Duration(days: 1)).toIso8601String() ?? '',
        ];
      }

      int compartmentCount = 0;
      int archiveCount = 0;
      int documentCount = 0;

      try {
        final totalCompartments =
            await db.rawQuery('SELECT COUNT(*) as count FROM compartments');
        compartmentCount = (totalCompartments.isNotEmpty
                ? totalCompartments.first['count'] as int?
                : null) ??
            0;
      } catch (e) {
        print('Erreur compartments: $e');
      }

      try {
        final totalArchives =
            await db.rawQuery('SELECT COUNT(*) as count FROM archives');
        archiveCount = (totalArchives.isNotEmpty
                ? totalArchives.first['count'] as int?
                : null) ??
            0;
      } catch (e) {
        print('Erreur archives: $e');
      }

      try {
        String docCountQuery = 'SELECT COUNT(*) as count FROM documents';
        if (dateFilter.isNotEmpty) {
          docCountQuery += dateFilter.replaceAll('d.', '');
        }
        final totalDocuments = await db.rawQuery(docCountQuery, dateArgs);
        documentCount = (totalDocuments.isNotEmpty
                ? totalDocuments.first['count'] as int?
                : null) ??
            0;
      } catch (e) {
        print('Erreur documents: $e');
      }

      List<Map<String, dynamic>> compartmentData = [];
      try {
        String compartmentQuery = '''
          SELECT 
            c.id,
            c.name as compartment_name,
            COUNT(DISTINCT a.id) as archive_count,
            COUNT(d.id) as document_count
          FROM compartments c
          LEFT JOIN archives a ON c.id = a.compartment_id
          LEFT JOIN documents d ON a.id = d.archive_id
        ''';

        if (dateFilter.isNotEmpty) {
          compartmentQuery += dateFilter;
        }

        compartmentQuery += '''
          GROUP BY c.id, c.name
          ORDER BY document_count DESC
        ''';

        compartmentData = await db.rawQuery(compartmentQuery, dateArgs);
      } catch (e) {
        print('Erreur compartment stats: $e');
      }

      List<Map<String, dynamic>> recentActivity = [];
      try {
        String activityQuery = '''
          SELECT 
            d.name as document_name,
            d.added_at,
            d.file_type,
            a.name as archive_name,
            c.name as compartment_name
          FROM documents d
          JOIN archives a ON d.archive_id = a.id
          JOIN compartments c ON a.compartment_id = c.id
        ''';

        if (dateFilter.isNotEmpty) {
          activityQuery += dateFilter;
        }

        activityQuery += '''
          ORDER BY d.added_at DESC
          LIMIT 50
        ''';

        recentActivity = await db.rawQuery(activityQuery, dateArgs);
      } catch (e) {
        print('Erreur recent activity: $e');
      }

      setState(() {
        _statistics = {
          'compartments': compartmentCount,
          'archives': archiveCount,
          'documents': documentCount,
        };
        _compartmentStats = compartmentData;
        _recentActivity = recentActivity;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur générale loadReports: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyDateFilter(String filterType) {
    setState(() {
      _filterType = filterType;
      final now = DateTime.now();

      switch (filterType) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'week':
          final startWeek = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(startWeek.year, startWeek.month, startWeek.day);
          _endDate = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'all':
          _startDate = null;
          _endDate = null;
          break;
      }
    });

    _loadReports();
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(
              start: _startDate ?? DateTime.now(),
              end: _endDate ?? DateTime.now())
          : null,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterType = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReports();
    }
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtrer par période',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.all_inclusive, color: Colors.blue.shade700),
                title: const Text('Tout'),
                trailing: _filterType == 'all'
                    ? Icon(Icons.check, color: Colors.blue.shade700)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _applyDateFilter('all');
                },
              ),
              ListTile(
                leading: Icon(Icons.today, color: Colors.blue.shade700),
                title: const Text('Aujourd\'hui'),
                trailing: _filterType == 'today'
                    ? Icon(Icons.check, color: Colors.blue.shade700)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _applyDateFilter('today');
                },
              ),
              ListTile(
                leading: Icon(Icons.view_week, color: Colors.blue.shade700),
                title: const Text('Cette semaine'),
                trailing: _filterType == 'week'
                    ? Icon(Icons.check, color: Colors.blue.shade700)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _applyDateFilter('week');
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.calendar_month, color: Colors.blue.shade700),
                title: const Text('Ce mois'),
                trailing: _filterType == 'month'
                    ? Icon(Icons.check, color: Colors.blue.shade700)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _applyDateFilter('month');
                },
              ),
              ListTile(
                leading: Icon(Icons.date_range, color: Colors.blue.shade700),
                title: const Text('Personnalisé'),
                trailing: _filterType == 'custom'
                    ? Icon(Icons.check, color: Colors.blue.shade700)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _selectCustomDateRange();
                },
              ),
              if (_startDate != null && _endDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Période: ${DateFormat('dd/MM/yyyy').format(_startDate ?? DateTime.now())} - ${DateFormat('dd/MM/yyyy').format(_endDate ?? DateTime.now())}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generatePdfReport() async {
    try {
      print('=== DÉBUT GÉNÉRATION PDF ===');

      if (_statistics.isEmpty || _isLoading) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chargement des données en cours...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        await _loadReports();
      }

      if (_statistics.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Aucune donnée à exporter. Veuillez actualiser les rapports.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'rapport_archives_$timestamp.pdf';

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le rapport PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Génération du rapport annulée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Génération du PDF en cours...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
                ),
              ),
              child: pw.Text(
                'Bureau du Leader - Secrétariat Général',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Document confidentiel',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // EN-TÊTE PROFESSIONNEL
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'RAPPORT D\'ANALYSE DES ARCHIVES',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Système de Gestion Documentaire - CMCI',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // INFORMATIONS DU RAPPORT
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Date de génération:',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          DateFormat('dd MMMM yyyy à HH:mm')
                              .format(DateTime.now()),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Période analysée:',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        if (_startDate != null && _endDate != null)
                          pw.Text(
                            '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                            style: const pw.TextStyle(fontSize: 10),
                          )
                        else
                          pw.Text(
                            'Toutes les données',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // SECTION 1: RÉSUMÉ EXÉCUTIF
              _buildPdfSectionTitle('1. RÉSUMÉ EXÉCUTIF'),
              pw.SizedBox(height: 12),

              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  _buildPdfSummaryRow(
                    'Nombre total de compartiments',
                    (_statistics['compartments'] ?? 0).toString(),
                    isFirst: true,
                  ),
                  _buildPdfSummaryRow(
                    'Nombre total d\'archives',
                    (_statistics['archives'] ?? 0).toString(),
                  ),
                  _buildPdfSummaryRow(
                    'Nombre total de documents',
                    (_statistics['documents'] ?? 0).toString(),
                  ),
                  _buildPdfSummaryRow(
                    'Moyenne de documents par archive',
                    _statistics['archives'] != null &&
                            _statistics['archives'] > 0
                        ? ((_statistics['documents'] ?? 0) /
                                _statistics['archives'])
                            .toStringAsFixed(1)
                        : '0',
                  ),
                ],
              ),

              pw.SizedBox(height: 28),

              // SECTION 2: ANALYSE PAR COMPARTIMENT
              _buildPdfSectionTitle('2. ANALYSE DÉTAILLÉE PAR COMPARTIMENT'),
              pw.SizedBox(height: 12),

              if (_compartmentStats.isNotEmpty)
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.blue700),
                      children: [
                        _buildPdfHeaderCell('COMPARTIMENT'),
                        _buildPdfHeaderCell('ARCHIVES',
                            align: pw.TextAlign.center),
                        _buildPdfHeaderCell('DOCUMENTS',
                            align: pw.TextAlign.center),
                        _buildPdfHeaderCell('DOC/ARCH',
                            align: pw.TextAlign.center),
                      ],
                    ),
                    ..._compartmentStats.asMap().entries.map((entry) {
                      final stat = entry.value;
                      final archiveCount = stat['archive_count'] ?? 0;
                      final documentCount = stat['document_count'] ?? 0;
                      final ratio = archiveCount > 0
                          ? (documentCount / archiveCount).toStringAsFixed(1)
                          : '0';

                      return pw.TableRow(
                        decoration: entry.key % 2 == 0
                            ? const pw.BoxDecoration(color: PdfColors.grey100)
                            : null,
                        children: [
                          _buildPdfDataCell(
                              stat['compartment_name']?.toString() ?? 'N/A'),
                          _buildPdfDataCell(archiveCount.toString(),
                              align: pw.TextAlign.center),
                          _buildPdfDataCell(documentCount.toString(),
                              align: pw.TextAlign.center),
                          _buildPdfDataCell(ratio, align: pw.TextAlign.center),
                        ],
                      );
                    }),
                  ],
                )
              else
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Aucune donnée disponible pour cette période',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ),

              pw.SizedBox(height: 28),

              // SECTION 3: ACTIVITÉ RÉCENTE
              _buildPdfSectionTitle('3. JOURNAL D\'ACTIVITÉ RÉCENTE'),
              pw.SizedBox(height: 8),
              pw.Text(
                'Liste des 25 derniers documents ajoutés',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 8),

              if (_recentActivity.isNotEmpty)
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.blue700),
                      children: [
                        _buildPdfHeaderCell('DOCUMENT'),
                        _buildPdfHeaderCell('COMPARTIMENT'),
                        _buildPdfHeaderCell('ARCHIVE'),
                        _buildPdfHeaderCell('DATE AJOUT'),
                      ],
                    ),
                    ..._recentActivity
                        .take(25)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final activity = entry.value;
                      String dateStr = 'N/A';
                      try {
                        if (activity['added_at'] != null) {
                          dateStr = DateFormat('dd/MM/yyyy HH:mm')
                              .format(DateTime.parse(activity['added_at']));
                        }
                      } catch (e) {
                        dateStr = 'N/A';
                      }

                      return pw.TableRow(
                        decoration: entry.key % 2 == 0
                            ? const pw.BoxDecoration(color: PdfColors.grey100)
                            : null,
                        children: [
                          _buildPdfDataCell(
                              activity['document_name']?.toString() ?? 'N/A'),
                          _buildPdfDataCell(
                              activity['compartment_name']?.toString() ??
                                  'N/A'),
                          _buildPdfDataCell(
                              activity['archive_name']?.toString() ?? 'N/A'),
                          _buildPdfDataCell(dateStr, fontSize: 8),
                        ],
                      );
                    }),
                  ],
                )
              else
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Aucune activité enregistrée pour cette période',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ),

              pw.SizedBox(height: 28),

              // NOTES ET OBSERVATIONS
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NOTES ET OBSERVATIONS',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '• Ce rapport a été généré automatiquement par le système de gestion documentaire.',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      '• Les statistiques reflètent l\'état de la base de données au moment de la génération.',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      '• Pour toute question concernant ce rapport, veuillez contacter le service de gestion des archives.',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // SIGNATURE FINALE
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Généré automatiquement par Gestionnaire d\'Archives - Bureau du Leader',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Secrétariat Général - Système de Gestion Documentaire',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ];
          },
        ),
      );

      final file = File(outputPath);
      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rapport PDF généré avec succès !'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OUVRIR',
              textColor: Colors.white,
              onPressed: () async {
                await OpenFile.open(file.path);
              },
            ),
          ),
        );

        await OpenFile.open(file.path);
      }

      print('=== FIN GÉNÉRATION PDF RÉUSSIE ===');
    } catch (e, stackTrace) {
      print('=== ERREUR PDF ===');
      print('ERREUR: $e');
      print('STACK TRACE: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur lors de la génération du PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  // Fonctions d'aide pour le PDF
  pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 4, color: PdfColors.blue700),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  pw.TableRow _buildPdfSummaryRow(String label, String value,
      {bool isFirst = false}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isFirst ? PdfColors.blue50 : null,
      ),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey100,
          ),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfHeaderCell(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildPdfDataCell(String text,
      {pw.TextAlign align = pw.TextAlign.left, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: fontSize),
        textAlign: align,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('Rapports'),
            const Spacer(),
            if (_startDate != null && _endDate != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )
            else if (_filterType != 'all')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _filterType == 'today'
                          ? 'Aujourd\'hui'
                          : _filterType == 'week'
                              ? 'Cette semaine'
                              : 'Ce mois',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterMenu,
            tooltip: 'Filtres',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdfReport,
            tooltip: 'Générer PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewSection(),
                    const SizedBox(height: 32),
                    _buildCompartmentStatsSection(),
                    const SizedBox(height: 32),
                    _buildRecentActivitySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Compartiments',
                (_statistics['compartments'] ?? 0).toString(),
                Icons.folder,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Archives',
                (_statistics['archives'] ?? 0).toString(),
                Icons.archive,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Documents',
                (_statistics['documents'] ?? 0).toString(),
                Icons.description,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompartmentStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiques par compartiment',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: _compartmentStats.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'Aucune donnée disponible',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                          label: Text('Compartiment',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Archives',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Documents',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _compartmentStats.map((stat) {
                      return DataRow(
                        cells: [
                          DataCell(Text(
                              stat['compartment_name']?.toString() ?? 'N/A')),
                          DataCell(
                              Text((stat['archive_count'] ?? 0).toString())),
                          DataCell(
                              Text((stat['document_count'] ?? 0).toString())),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activité récente',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: _recentActivity.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'Aucune activité récente',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentActivity.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final activity = _recentActivity[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(Icons.description,
                            color: Colors.blue.shade700, size: 20),
                      ),
                      title: Text(
                        activity['document_name']?.toString() ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${activity['compartment_name']?.toString() ?? 'N/A'} > ${activity['archive_name']?.toString() ?? 'N/A'}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: Text(
                        _formatDate(activity['added_at']?.toString()),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }
}
