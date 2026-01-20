import 'package:flutter/material.dart';
import '../database.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  List<SearchResult> _results = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await _searchInDatabase(query.toLowerCase());
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de recherche: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<SearchResult>> _searchInDatabase(String query) async {
    final results = <SearchResult>[];
    final db = await DatabaseHelper.instance.database;

    final compartments = await db.rawQuery('''
      SELECT id, name, description FROM compartments
      WHERE LOWER(name) LIKE ? OR LOWER(description) LIKE ?
    ''', ['%$query%', '%$query%']);

    for (var comp in compartments) {
      results.add(SearchResult(
        type: SearchResultType.compartment,
        compartmentId: comp['id'] as int,
        compartmentName: comp['name'] as String,
        title: comp['name'] as String,
        subtitle: comp['description'] as String?,
      ));
    }

    final archives = await db.rawQuery('''
      SELECT a.id, a.name, a.subtitle, c.id as comp_id, c.name as comp_name
      FROM archives a
      JOIN compartments c ON a.compartment_id = c.id
      WHERE LOWER(a.name) LIKE ? OR LOWER(a.subtitle) LIKE ?
    ''', ['%$query%', '%$query%']);

    for (var arc in archives) {
      results.add(SearchResult(
        type: SearchResultType.archive,
        compartmentId: arc['comp_id'] as int,
        compartmentName: arc['comp_name'] as String,
        archiveId: arc['id'] as int,
        archiveName: arc['name'] as String,
        title: arc['name'] as String,
        subtitle: arc['subtitle'] as String?,
      ));
    }

    final documents = await db.rawQuery('''
      SELECT d.id, d.name, d.file_path, d.file_type,
             a.id as arc_id, a.name as arc_name,
             c.id as comp_id, c.name as comp_name
      FROM documents d
      JOIN archives a ON d.archive_id = a.id
      JOIN compartments c ON a.compartment_id = c.id
      WHERE LOWER(d.name) LIKE ?
    ''', ['%$query%']);

    for (var doc in documents) {
      results.add(SearchResult(
        type: SearchResultType.document,
        compartmentId: doc['comp_id'] as int,
        compartmentName: doc['comp_name'] as String,
        archiveId: doc['arc_id'] as int,
        archiveName: doc['arc_name'] as String,
        documentId: doc['id'] as int,
        title: doc['name'] as String,
        subtitle: doc['file_path'] as String?,
        fileType: doc['file_type'] as String?,
      ));
    }

    return results;
  }

  void _navigateToResult(SearchResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getResultIcon(result.type), color: _getResultColor(result.type)),
            const SizedBox(width: 12),
            Expanded(child: Text(result.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${_getResultTypeLabel(result.type)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (result.subtitle != null) ...[
              Text('Description: ${result.subtitle}'),
              const SizedBox(height: 8),
            ],
            Text(
              'Emplacement:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(result.getLocationPath()),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Pour accéder à cet élément, rendez-vous dans "Mes Archives" et naviguez dans l\'arborescence.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Ici vous pouvez ajouter la navigation vers la page Mes Archives
              // en pré-sélectionnant le compartiment/archive approprié
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez naviguer manuellement vers "Mes Archives"'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Aller aux Archives'),
          ),
        ],
      ),
    );
  }

  IconData _getResultIcon(SearchResultType type) {
    switch (type) {
      case SearchResultType.compartment:
        return Icons.folder;
      case SearchResultType.archive:
        return Icons.archive;
      case SearchResultType.document:
        return Icons.description;
    }
  }

  Color _getResultColor(SearchResultType type) {
    switch (type) {
      case SearchResultType.compartment:
        return Colors.blue;
      case SearchResultType.archive:
        return Colors.green;
      case SearchResultType.document:
        return Colors.orange;
    }
  }

  String _getResultTypeLabel(SearchResultType type) {
    switch (type) {
      case SearchResultType.compartment:
        return 'Compartiment';
      case SearchResultType.archive:
        return 'Archive';
      case SearchResultType.document:
        return 'Document';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('Rechercher'),
            const SizedBox(width: 24),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    if (value.length >= 2) {
                      _performSearch(value);
                    } else if (value.isEmpty) {
                      _performSearch('');
                    }
                  },
                  onSubmitted: _performSearch,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    '${_results.length} résultat(s) pour "$_searchQuery"',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty && _searchQuery.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun résultat trouvé',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Essayez avec des mots-clés différents',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _searchQuery.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Commencez à taper pour rechercher',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Recherchez parmi vos compartiments, archives et documents',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final result = _results[index];
                              return TweenAnimationBuilder(
                                duration: Duration(milliseconds: 300 + (index * 50)),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, double value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Opacity(
                                      opacity: value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getResultColor(result.type).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getResultIcon(result.type),
                                        color: _getResultColor(result.type),
                                        size: 28,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getResultColor(result.type),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getResultTypeLabel(result.type),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            result.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (result.subtitle != null) ...[
                                          const SizedBox(height: 4),
                                          Text(result.subtitle!),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                result.getLocationPath(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _navigateToResult(result),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

enum SearchResultType { compartment, archive, document }

class SearchResult {
  final SearchResultType type;
  final int compartmentId;
  final String compartmentName;
  final int? archiveId;
  final String? archiveName;
  final int? documentId;
  final String title;
  final String? subtitle;
  final String? fileType;

  SearchResult({
    required this.type,
    required this.compartmentId,
    required this.compartmentName,
    this.archiveId,
    this.archiveName,
    this.documentId,
    required this.title,
    this.subtitle,
    this.fileType,
  });

  String getLocationPath() {
    switch (type) {
      case SearchResultType.compartment:
        return 'Compartiment: $compartmentName';
      case SearchResultType.archive:
        return 'Compartiment: $compartmentName';
      case SearchResultType.document:
        return 'Compartiment: $compartmentName > Archive: $archiveName';
    }
  }
}