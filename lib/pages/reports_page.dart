import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // Statistiques globales
      final totalCompartments = await db.rawQuery('SELECT COUNT(*) as count FROM compartments');
      final totalArchives = await db.rawQuery('SELECT COUNT(*) as count FROM archives');
      final totalDocuments = await db.rawQuery('SELECT COUNT(*) as count FROM documents');

      // Statistiques par compartiment
      final compartmentData = await db.rawQuery('''
        SELECT 
          c.id,
          c.name as compartment_name,
          COUNT(DISTINCT a.id) as archive_count,
          COUNT(d.id) as document_count
        FROM compartments c
        LEFT JOIN archives a ON c.id = a.compartment_id
        LEFT JOIN documents d ON a.id = d.archive_id
        GROUP BY c.id, c.name
        ORDER BY document_count DESC
      ''');

      // Activité récente
      final recentActivity = await db.rawQuery('''
        SELECT 
          d.name as document_name,
          d.added_at,
          a.name as archive_name,
          c.name as compartment_name
        FROM documents d
        JOIN archives a ON d.archive_id = a.id
        JOIN compartments c ON a.compartment_id = c.id
        ORDER BY d.added_at DESC
        LIMIT 10
      ''');

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
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité d\'impression à venir')),
              );
            },
            tooltip: 'Imprimer',
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