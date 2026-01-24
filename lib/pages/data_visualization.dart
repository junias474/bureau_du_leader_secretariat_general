import 'package:flutter/material.dart';
import '../database.dart';

class DataVisualizationPage extends StatefulWidget {
  const DataVisualizationPage({super.key});

  @override
  State<DataVisualizationPage> createState() => _DataVisualizationPageState();
}

class _DataVisualizationPageState extends State<DataVisualizationPage> {
  String _selectedTable = 'compartments';
  List<Map<String, dynamic>> _tableData = [];
  List<Map<String, dynamic>> _filteredTableData = [];
  List<String> _columnNames = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _tableLabels = {
    'compartments': 'Compartiments',
    'archives': 'Archives',
    'documents': 'Documents',
    'locked_archives_settings': 'Paramètres Archives Verrouillées',
  };

  @override
  void initState() {
    super.initState();
    _loadTableData();
    _searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredTableData = _tableData;
      });
      return;
    }

    setState(() {
      _filteredTableData = _tableData.where((row) {
        return row.values.any((value) {
          if (value == null) return false;
          return value.toString().toLowerCase().contains(query);
        });
      }).toList();
    });
  }

  Future<void> _loadTableData() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.rawQuery('SELECT * FROM $_selectedTable');

      if (data.isNotEmpty) {
        setState(() {
          _tableData = data;
          _filteredTableData = data;
          _columnNames = data.first.keys.toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _tableData = [];
          _filteredTableData = [];
          _columnNames = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _tableData = [];
        _filteredTableData = [];
        _columnNames = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
        title: Row(
          children: [
            // Titre à l'extrême gauche
            const Text(
              'Visualisation des Données',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 12),
            // Champ de recherche à droite
            Expanded(
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  style: TextStyle(color: Colors.grey[800]),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTableData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur de table
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  'Table:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: _tableLabels.entries.map((entry) {
                      return ButtonSegment<String>(
                        value: entry.key,
                        label: Text(entry.value),
                        icon: Icon(_getTableIcon(entry.key)),
                      );
                    }).toList(),
                    selected: {_selectedTable},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedTable = newSelection.first;
                        _searchController.clear();
                      });
                      _loadTableData();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tableau de données
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTableData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchController.text.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.table_chart_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Aucun résultat trouvé'
                                  : 'Aucune donnée dans cette table',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Colors.blue[50],
                              ),
                              headingRowHeight: 48,
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 60,
                              horizontalMargin: 12,
                              columnSpacing: 16,
                              border: TableBorder.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              columns: _columnNames.map((columnName) {
                                return DataColumn(
                                  label: Expanded(
                                    child: Text(
                                      _formatColumnName(columnName),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                              rows: _filteredTableData.map((row) {
                                return DataRow(
                                  cells: _columnNames.map((columnName) {
                                    final value = row[columnName];
                                    final formattedValue =
                                        _formatCellValue(columnName, value);

                                    return DataCell(
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: _getColumnWidth(columnName),
                                          minWidth:
                                              _getColumnWidth(columnName) * 0.5,
                                        ),
                                        child: Tooltip(
                                          message: formattedValue,
                                          child: Text(
                                            formattedValue,
                                            style: TextStyle(
                                              color: _getCellColor(
                                                  columnName, value),
                                              fontWeight:
                                                  _isBoldColumn(columnName)
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),

          // Statistiques en bas
          if (!_isLoading && _tableData.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dataset, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'Résultats: ${_filteredTableData.length} / ${_tableData.length}'
                            : 'Total: ${_tableData.length} enregistrement(s)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.view_column,
                          color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_columnNames.length} colonne(s)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getTableIcon(String tableName) {
    switch (tableName) {
      case 'compartments':
        return Icons.folder;
      case 'archives':
        return Icons.archive;
      case 'documents':
        return Icons.description;
      case 'locked_archives_settings':
        return Icons.lock;
      default:
        return Icons.table_chart;
    }
  }

  String _formatColumnName(String columnName) {
    // Formatage des noms de colonnes pour l'affichage
    final Map<String, String> translations = {
      'id': 'ID',
      'name': 'Nom',
      'description': 'Description',
      'created_at': 'Date de création',
      'compartment_id': 'ID Compartiment',
      'subtitle': 'Sous-titre',
      'is_locked': 'Verrouillé',
      'password_hash': 'Mot de passe (hash)',
      'archive_id': 'ID Archive',
      'file_path': 'Chemin du fichier',
      'file_type': 'Type de fichier',
      'added_at': 'Ajouté le',
    };

    return translations[columnName] ?? columnName;
  }

  String _formatCellValue(String columnName, dynamic value) {
    // Gérer les valeurs nulles avec des textes appropriés
    if (value == null || value.toString().isEmpty) {
      if (columnName == 'description' || columnName == 'subtitle') {
        return '-';
      } else if (columnName == 'password_hash') {
        return '-';
      } else {
        return '-';
      }
    }

    // Masquer les hash de mots de passe
    if (columnName == 'password_hash') {
      return '••••••••••••';
    }

    // Formater les dates
    if (columnName.contains('_at') || columnName == 'created_at') {
      try {
        final date = DateTime.parse(value.toString());
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return value.toString();
      }
    }

    // Formater les booléens
    if (columnName == 'is_locked') {
      return value == 1 ? 'Oui 🔒' : 'Non';
    }

    return value.toString();
  }

  Color _getCellColor(String columnName, dynamic value) {
    // Couleur spéciale pour les colonnes sensibles
    if (columnName == 'password_hash') {
      return Colors.red[700]!;
    }

    if (columnName == 'is_locked' && value == 1) {
      return Colors.orange[700]!;
    }

    return Colors.grey[800]!;
  }

  bool _isBoldColumn(String columnName) {
    return columnName == 'id' || columnName == 'name';
  }

  double _getColumnWidth(String columnName) {
    // Définir des largeurs optimales pour chaque type de colonne
    switch (columnName) {
      case 'id':
        return 60;
      case 'name':
        return 200;
      case 'description':
        return 250;
      case 'subtitle':
        return 180;
      case 'created_at':
      case 'added_at':
        return 140;
      case 'is_locked':
        return 100;
      case 'password_hash':
        return 120;
      case 'compartment_id':
      case 'archive_id':
        return 120;
      case 'file_path':
        return 280;
      case 'file_type':
        return 100;
      default:
        return 150;
    }
  }
}
