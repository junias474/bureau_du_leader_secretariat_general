import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

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
  String _filterType = 'all'; // 'all', 'today', 'week', 'month', 'custom'

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // Construire la clause WHERE pour le filtrage de dates
      String dateFilter = '';
      List<dynamic> dateArgs = [];
      
      if (_startDate != null && _endDate != null) {
        dateFilter = ' WHERE d.added_at BETWEEN ? AND ?';
        dateArgs = [
          _startDate!.toIso8601String(),
          _endDate!.add(const Duration(days: 1)).toIso8601String(),
        ];
      }

      // Statistiques globales
      final totalCompartments = await db.rawQuery('SELECT COUNT(*) as count FROM compartments');
      final totalArchives = await db.rawQuery('SELECT COUNT(*) as count FROM archives');
      
      String docCountQuery = 'SELECT COUNT(*) as count FROM documents';
      if (dateFilter.isNotEmpty) {
        docCountQuery += dateFilter.replaceAll('d.', '');
      }
      final totalDocuments = await db.rawQuery(docCountQuery, dateArgs);

      // Statistiques par compartiment avec filtrage
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

      final compartmentData = await db.rawQuery(compartmentQuery, dateArgs);

      // Activité récente avec filtrage
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

      final recentActivity = await db.rawQuery(activityQuery, dateArgs);

      setState(() {
        _statistics = {
          'compartments': totalCompartments.first['count'],
          'archives': totalArchives.first['count'],
          'documents': totalDocuments.first['count'],
        };
        _compartmentStats = compartmentData;
        _recentActivity = recentActivity;
        _isLoading = false;
      });
    } catch (e) {
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
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
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
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue[700]!),
          ),
          child: child!,
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

  Future<void> _generatePdfReport() async {
    try {
      final pdf = pw.Document();

      // Créer le PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // En-tête
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 2, color: PdfColors.blue700),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RAPPORT D\'ARCHIVES',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Gestionnaire d\'Archives - CMCI',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Département de la Communication',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Date du rapport: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        if (_startDate != null && _endDate != null)
                          pw.Text(
                            'Période: ${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 24),
              
              // Vue d'ensemble
              pw.Text(
                'VUE D\'ENSEMBLE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 12),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfStatCard('Compartiments', _statistics['compartments']?.toString() ?? '0'),
                  _buildPdfStatCard('Archives', _statistics['archives']?.toString() ?? '0'),
                  _buildPdfStatCard('Documents', _statistics['documents']?.toString() ?? '0'),
                ],
              ),
              
              pw.SizedBox(height: 24),
              
              // Statistiques par compartiment
              pw.Text(
                'STATISTIQUES PAR COMPARTIMENT',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 12),
              
              if (_compartmentStats.isNotEmpty)
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    // En-tête
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                      children: [
                        _buildPdfTableCell('Compartiment', isHeader: true),
                        _buildPdfTableCell('Archives', isHeader: true),
                        _buildPdfTableCell('Documents', isHeader: true),
                      ],
                    ),
                    // Données
                    ..._compartmentStats.map((stat) {
                      return pw.TableRow(
                        children: [
                          _buildPdfTableCell(stat['compartment_name']),
                          _buildPdfTableCell(stat['archive_count'].toString(), align: pw.TextAlign.center),
                          _buildPdfTableCell(stat['document_count'].toString(), align: pw.TextAlign.center),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              
              pw.SizedBox(height: 24),
              
              // Activité récente
              pw.Text(
                'ACTIVITÉ RÉCENTE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 12),
              
              if (_recentActivity.isNotEmpty)
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // En-tête
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                      children: [
                        _buildPdfTableCell('Document', isHeader: true),
                        _buildPdfTableCell('Compartiment', isHeader: true),
                        _buildPdfTableCell('Archive', isHeader: true),
                        _buildPdfTableCell('Date', isHeader: true),
                      ],
                    ),
                    // Données (limité à 20 pour le PDF)
                    ..._recentActivity.take(20).map((activity) {
                      return pw.TableRow(
                        children: [
                          _buildPdfTableCell(activity['document_name']),
                          _buildPdfTableCell(activity['compartment_name']),
                          _buildPdfTableCell(activity['archive_name']),
                          _buildPdfTableCell(
                            DateFormat('dd/MM/yyyy').format(DateTime.parse(activity['added_at'])),
                            fontSize: 8,
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              
              // Pied de page
              pw.SizedBox(height: 32),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Généré par Gestionnaire d\'Archives - CMCI',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} sur ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Sauvegarder le PDF
      final output = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${output.path}/ArchiveManager/rapport_$timestamp.pdf');
      
      // Créer le répertoire s'il n'existe pas
      await file.parent.create(recursive: true);
      
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rapport PDF généré: ${file.path}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OUVRIR',
              textColor: Colors.white,
              onPressed: () async {
                await Printing.sharePdf(bytes: await pdf.save(), filename: 'rapport_$timestamp.pdf');
              },
            ),
          ),
        );
        
        // Afficher aussi l'aperçu
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _buildPdfStatCard(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        title: const Text('Rapports'),
        actions: [
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
      body: Column(
        children: [
          // Barre de filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrer par période',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('Tout', 'all'),
                    _buildFilterChip('Aujourd\'hui', 'today'),
                    _buildFilterChip('Cette semaine', 'week'),
                    _buildFilterChip('Ce mois', 'month'),
                    _buildFilterChip('Personnalisé', 'custom', isCustom: true),
                  ],
                ),
                if (_startDate != null && _endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.date_range, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Du ${DateFormat('dd/MM/yyyy').format(_startDate!)} au ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                            style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Contenu
          Expanded(
            child: _isLoading
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isCustom = false}) {
    final isSelected = _filterType == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (isCustom) {
          _selectCustomDateRange();
        } else {
          _applyDateFilter(value);
        }
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[700] : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Compartiments',
                _statistics['compartments']?.toString() ?? '0',
                Icons.folder,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Archives',
                _statistics['archives']?.toString() ?? '0',
                Icons.archive,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Documents',
                _statistics['documents']?.toString() ?? '0',
                Icons.description,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            color: Colors.grey[800],
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
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Compartiment', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Archives', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _compartmentStats.map((stat) {
                      return DataRow(
                        cells: [
                          DataCell(Text(stat['compartment_name'])),
                          DataCell(Text(stat['archive_count'].toString())),
                          DataCell(Text(stat['document_count'].toString())),
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
            color: Colors.grey[800],
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
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentActivity.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final activity = _recentActivity[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.description, color: Colors.blue[700], size: 20),
                      ),
                      title: Text(
                        activity['document_name'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${activity['compartment_name']} > ${activity['archive_name']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        _formatDate(activity['added_at']),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }
}