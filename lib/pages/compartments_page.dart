import 'package:flutter/material.dart';
import 'compartments_manager.dart';
import 'archives_manager.dart';
import 'documents_manager.dart';

class CompartmentsPage extends StatefulWidget {
  const CompartmentsPage({Key? key}) : super(key: key);

  @override
  State<CompartmentsPage> createState() => _CompartmentsPageState();
}

class _CompartmentsPageState extends State<CompartmentsPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _selectedCompartment;
  Map<String, dynamic>? _selectedArchive;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // GlobalKeys pour accéder aux méthodes des managers
  final _compartmentsKey = GlobalKey<CompartmentsManagerState>();
  final _archivesKey = GlobalKey<ArchivesManagerState>();
  final _documentsKey = GlobalKey<DocumentsManagerState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _selectCompartment(Map<String, dynamic> compartment) {
    setState(() {
      _selectedCompartment = compartment;
      _selectedArchive = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _animationController.forward(from: 0);
  }

  void _selectArchive(Map<String, dynamic> archive) {
    setState(() {
      _selectedArchive = archive;
      _searchQuery = '';
      _searchController.clear();
    });
    _animationController.forward(from: 0);
  }

  void _goBack() {
    if (_selectedArchive != null) {
      setState(() {
        _selectedArchive = null;
        _searchQuery = '';
        _searchController.clear();
      });
      _animationController.forward(from: 0);
    } else if (_selectedCompartment != null) {
      setState(() {
        _selectedCompartment = null;
        _searchQuery = '';
        _searchController.clear();
      });
      _animationController.forward(from: 0);
    }
  }

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          if (_selectedCompartment != null || _selectedArchive != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBack,
            ),
          const Icon(Icons.home, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          if (_selectedCompartment != null) ...[
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              _selectedCompartment!['name'],
              style: TextStyle(
                fontWeight: _selectedArchive == null
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _selectedArchive == null
                    ? Colors.blue[700]
                    : Colors.grey[700],
              ),
            ),
          ],
          if (_selectedArchive != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            if (_selectedArchive!['is_locked'] == 1)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.lock, size: 16, color: Colors.orange[700]),
              ),
            Text(
              _selectedArchive!['name'],
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue[700]),
            ),
          ],
        ],
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
        title: Row(
          children: [
            Text(
              _selectedArchive != null
                  ? 'Documents'
                  : _selectedCompartment != null
                      ? 'Archives'
                      : 'Mes Archives',
            ),
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
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white, size: 20),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedArchive != null) {
                _documentsKey.currentState?.loadDocuments();
              } else if (_selectedCompartment != null) {
                _archivesKey.currentState?.loadArchives();
              } else {
                _compartmentsKey.currentState?.loadCompartments();
              }
            },
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumb(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _selectedArchive != null
                  ? DocumentsManager(
                      key: _documentsKey,
                      archiveId: _selectedArchive!['id'],
                      searchQuery: _searchQuery,
                    )
                  : _selectedCompartment != null
                      ? ArchivesManager(
                          key: _archivesKey,
                          compartmentId: _selectedCompartment!['id'],
                          onArchiveSelected: _selectArchive,
                          searchQuery: _searchQuery,
                        )
                      : CompartmentsManager(
                          key: _compartmentsKey,
                          onCompartmentSelected: _selectCompartment,
                          searchQuery: _searchQuery,
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedArchive != null) {
            _documentsKey.currentState?.showAddDocumentDialog();
          } else if (_selectedCompartment != null) {
            _archivesKey.currentState?.showArchiveDialog();
          } else {
            _compartmentsKey.currentState?.showCompartmentDialog();
          }
        },
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.add),
        label: Text(
          _selectedArchive != null
              ? 'Document'
              : _selectedCompartment != null
                  ? 'Archive'
                  : 'Compartiment',
        ),
      ),
    );
  }
}