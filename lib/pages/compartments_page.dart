import 'package:flutter/material.dart';
import '../database.dart';

class CompartmentsPage extends StatefulWidget {
  const CompartmentsPage({Key? key}) : super(key: key);

  @override
  State<CompartmentsPage> createState() => _CompartmentsPageState();
}

class _CompartmentsPageState extends State<CompartmentsPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _compartments = [];
  Map<String, dynamic>? _selectedCompartment;
  List<Map<String, dynamic>> _archives = [];
  Map<String, dynamic>? _selectedArchive;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _loadCompartments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCompartments() async {
    setState(() => _isLoading = true);
    final compartments = await DatabaseHelper.instance.getCompartments();
    setState(() {
      _compartments = compartments;
      _isLoading = false;
    });
    _animationController.forward(from: 0);
  }

  Future<void> _loadArchives(int compartmentId) async {
    final archives = await DatabaseHelper.instance.getArchives(compartmentId);
    setState(() {
      _archives = archives;
      _selectedArchive = null;
      _documents = [];
    });
    _animationController.forward(from: 0);
  }

  Future<void> _loadDocuments(int archiveId) async {
    final documents = await DatabaseHelper.instance.getDocuments(archiveId);
    setState(() {
      _documents = documents;
    });
    _animationController.forward(from: 0);
  }

  void _selectCompartment(Map<String, dynamic> compartment) {
    setState(() {
      _selectedCompartment = compartment;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadArchives(compartment['id']);
  }

  void _selectArchive(Map<String, dynamic> archive) {
    setState(() {
      _selectedArchive = archive;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadDocuments(archive['id']);
  }

  void _goBack() {
    if (_selectedArchive != null) {
      setState(() {
        _selectedArchive = null;
        _documents = [];
        _searchQuery = '';
        _searchController.clear();
      });
      _animationController.forward(from: 0);
    } else if (_selectedCompartment != null) {
      setState(() {
        _selectedCompartment = null;
        _archives = [];
        _searchQuery = '';
        _searchController.clear();
      });
      _animationController.forward(from: 0);
    }
  }

  List<Map<String, dynamic>> get _filteredCompartments {
    if (_searchQuery.isEmpty) return _compartments;
    return _compartments.where((comp) {
      final name = (comp['name'] as String).toLowerCase();
      final description =
          ((comp['description'] as String?) ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredArchives {
    if (_searchQuery.isEmpty) return _archives;
    return _archives.where((arc) {
      final name = (arc['name'] as String).toLowerCase();
      final subtitle = ((arc['subtitle'] as String?) ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || subtitle.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    if (_searchQuery.isEmpty) return _documents;
    return _documents.where((doc) {
      final name = (doc['name'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  void _showCompartmentDialog({Map<String, dynamic>? compartment}) {
    final isEditing = compartment != null;
    final nameController =
        TextEditingController(text: compartment?['name'] ?? '');
    final descriptionController =
        TextEditingController(text: compartment?['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            isEditing ? 'Modifier le compartiment' : 'Nouveau compartiment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du compartiment *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom est obligatoire')),
                );
                return;
              }

              try {
                if (isEditing) {
                  await DatabaseHelper.instance.updateCompartment(
                    compartment['id'],
                    nameController.text.trim(),
                    descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  );
                } else {
                  await DatabaseHelper.instance.createCompartment(
                    nameController.text.trim(),
                    descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  );
                }

                if (!mounted) return;
                Navigator.pop(context);
                _loadCompartments();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(isEditing
                          ? 'Compartiment modifié'
                          : 'Compartiment créé')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Erreur: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text(isEditing ? 'Modifier' : 'Créer'),
          ),
        ],
      ),
    );
  }

  void _showArchiveDialog({Map<String, dynamic>? archive}) {
    if (_selectedCompartment == null) return;

    final isEditing = archive != null;
    final nameController = TextEditingController(text: archive?['name'] ?? '');
    final subtitleController =
        TextEditingController(text: archive?['subtitle'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Modifier l\'archive' : 'Nouvelle archive'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'archive *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Sous-titre (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom est obligatoire')),
                );
                return;
              }

              try {
                if (isEditing) {
                  await DatabaseHelper.instance.updateArchive(
                    archive['id'],
                    nameController.text.trim(),
                    subtitleController.text.trim().isEmpty
                        ? null
                        : subtitleController.text.trim(),
                  );
                } else {
                  await DatabaseHelper.instance.createArchive(
                    _selectedCompartment!['id'],
                    nameController.text.trim(),
                    subtitleController.text.trim().isEmpty
                        ? null
                        : subtitleController.text.trim(),
                  );
                }

                if (!mounted) return;
                Navigator.pop(context);
                _loadArchives(_selectedCompartment!['id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          isEditing ? 'Archive modifiée' : 'Archive créée')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Erreur: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text(isEditing ? 'Modifier' : 'Créer'),
          ),
        ],
      ),
    );
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
                _loadDocuments(_selectedArchive!['id']);
              } else if (_selectedCompartment != null) {
                _loadArchives(_selectedCompartment!['id']);
              } else {
                _loadCompartments();
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
                  ? _buildDocumentsGrid()
                  : _selectedCompartment != null
                      ? _buildArchivesGrid()
                      : _buildCompartmentsGrid(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedArchive != null) {
            // Ajouter document (sera implémenté)
          } else if (_selectedCompartment != null) {
            _showArchiveDialog();
          } else {
            _showCompartmentDialog();
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

  Widget _buildCompartmentsGrid() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredCompartments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Aucun compartiment',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredCompartments.length,
      itemBuilder: (context, index) {
        final compartment = _filteredCompartments[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                InkWell(
                  onTap: () => _selectCompartment(compartment),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Colors.blue[400]!, Colors.blue[600]!]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.folder,
                              size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          compartment['name'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (compartment['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            compartment['description'],
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.more_vert,
                          size: 20, color: Colors.grey),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showCompartmentDialog(compartment: compartment);
                      } else if (value == 'delete') {
                        _confirmDeleteCompartment(compartment);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 20),
                            SizedBox(width: 12),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Supprimer',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteCompartment(Map<String, dynamic> compartment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Confirmer la suppression'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voulez-vous vraiment supprimer le compartiment "${compartment['name']}" ?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette action supprimera également toutes les archives et documents associés !',
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteCompartment(compartment['id']);
        _loadCompartments();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compartiment supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildArchivesGrid() {
    if (_filteredArchives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Aucune archive',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredArchives.length,
      itemBuilder: (context, index) {
        final archive = _filteredArchives[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                InkWell(
                  onTap: () => _selectArchive(archive),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.archive,
                              size: 48, color: Colors.green[700]),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          archive['name'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (archive['subtitle'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            archive['subtitle'],
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.more_vert,
                          size: 20, color: Colors.grey),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showArchiveDialog(archive: archive);
                      } else if (value == 'delete') {
                        _confirmDeleteArchive(archive);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 20),
                            SizedBox(width: 12),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Supprimer',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteArchive(Map<String, dynamic> archive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Confirmer la suppression'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voulez-vous vraiment supprimer l\'archive "${archive['name']}" ?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette action supprimera également tous les documents associés !',
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteArchive(archive['id']);
        if (_selectedCompartment != null) {
          _loadArchives(_selectedCompartment!['id']);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Archive supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDocumentsGrid() {
    if (_filteredDocuments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Aucun document',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredDocuments.length,
      itemBuilder: (context, index) {
        final document = _filteredDocuments[index];
        final hasFile = (document['file_path'] as String?)?.isNotEmpty ?? false;

        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.description,
                              size: 40, color: Colors.orange[700]),
                        ),
                        const SizedBox(height: 8),
                        if (!hasFile)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('TITRE',
                                style: TextStyle(
                                    fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          document['name'],
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.more_vert,
                          size: 16, color: Colors.grey),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'view') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Fonctionnalité de visualisation à venir')),
                        );
                      } else if (value == 'delete') {
                        _confirmDeleteDocument(document);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility,
                                color: Colors.blue, size: 20),
                            SizedBox(width: 12),
                            Text('Voir'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Supprimer',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteDocument(Map<String, dynamic> document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Confirmer la suppression'),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer le document "${document['name']}" ?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteDocument(document['id']);
        if (_selectedArchive != null) {
          _loadDocuments(_selectedArchive!['id']);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
