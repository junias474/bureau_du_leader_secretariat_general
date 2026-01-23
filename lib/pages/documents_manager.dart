import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../database.dart';

class DocumentsManager extends StatefulWidget {
  final int archiveId;
  final String searchQuery;

  const DocumentsManager({
    super.key,
    required this.archiveId,
    required this.searchQuery,
  });

  @override
  State<DocumentsManager> createState() => DocumentsManagerState();
}

class DocumentsManagerState extends State<DocumentsManager>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _documents = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    loadDocuments();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadDocuments() async {
    final documents =
        await DatabaseHelper.instance.getDocuments(widget.archiveId);
    setState(() {
      _documents = documents;
    });
    _animationController.forward(from: 0);
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    if (widget.searchQuery.isEmpty) return _documents;
    return _documents.where((doc) {
      final name = (doc['name'] as String).toLowerCase();
      final query = widget.searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  Future<void> openDocument(Map<String, dynamic> document) async {
    final filePath = document['file_path'] as String?;

    // Vérifier si le document a un fichier associé
    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce document n\'a pas de fichier associé'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Vérifier si le fichier existe
    final file = File(filePath);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le fichier n\'existe plus sur le disque'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Ouvrir le fichier avec l'application par défaut
      final result = await OpenFile.open(filePath);

      if (!mounted) return;
      Navigator.pop(context); // Fermer l'indicateur de chargement

      // Vérifier le résultat de l'ouverture
      if (result.type != ResultType.done) {
        String message;
        switch (result.type) {
          case ResultType.noAppToOpen:
            message =
                'Aucune application installée pour ouvrir ce type de fichier';
            break;
          case ResultType.fileNotFound:
            message = 'Fichier introuvable';
            break;
          case ResultType.permissionDenied:
            message = 'Permission refusée pour ouvrir ce fichier';
            break;
          default:
            message =
                'Erreur lors de l\'ouverture du fichier: ${result.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fermer l'indicateur de chargement

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ouverture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> showAddDocumentDialog() async {
    final nameController = TextEditingController();
    String? selectedFilePath;
    String? selectedFileName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du document *',
                    border: OutlineInputBorder(),
                    hintText: 'Ex: Rapport mensuel',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: [
                        'pdf',
                        'doc',
                        'docx',
                        'xls',
                        'xlsx',
                        'txt',
                        'jpg',
                        'jpeg',
                        'png'
                      ],
                    );

                    if (result != null && result.files.single.path != null) {
                      setDialogState(() {
                        selectedFilePath = result.files.single.path;
                        selectedFileName = result.files.single.name;
                        if (nameController.text.trim().isEmpty) {
                          nameController.text =
                              path.basenameWithoutExtension(selectedFileName!);
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choisir un fichier (optionnel)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
                if (selectedFileName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFileName!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setDialogState(() {
                              selectedFilePath = null;
                              selectedFileName = null;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Vous pouvez créer un document titre sans fichier',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
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
                  String finalFilePath = '';
                  String? fileType;

                  if (selectedFilePath != null) {
                    final appDir = await getApplicationDocumentsDirectory();
                    final archiveDir = Directory(
                        path.join(appDir.path, 'ArchiveManager', 'documents'));
                    if (!await archiveDir.exists()) {
                      await archiveDir.create(recursive: true);
                    }

                    final timestamp =
                        DateTime.now().millisecondsSinceEpoch.toString();
                    final extension = path.extension(selectedFilePath!);
                    final newFileName =
                        '${timestamp}_${nameController.text.trim().replaceAll(' ', '_')}$extension';
                    finalFilePath = path.join(archiveDir.path, newFileName);

                    await File(selectedFilePath!).copy(finalFilePath);
                    fileType = extension.replaceAll('.', '');
                  }

                  await DatabaseHelper.instance.addDocument(
                    widget.archiveId,
                    nameController.text.trim(),
                    finalFilePath,
                    fileType,
                  );

                  if (!mounted) return;
                  Navigator.pop(context);
                  loadDocuments();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Document ajouté avec succès')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> confirmDeleteDocument(Map<String, dynamic> document) async {
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
        loadDocuments();
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

  @override
  Widget build(BuildContext context) {
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
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                InkWell(
                  onTap: () => openDocument(document),
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
                        if (hasFile) ...[
                          const SizedBox(height: 4),
                          Text(
                            document['file_type']?.toUpperCase() ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
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
                          size: 16, color: Colors.grey),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'open') {
                        openDocument(document);
                      } else if (value == 'delete') {
                        confirmDeleteDocument(document);
                      }
                    },
                    itemBuilder: (context) => [
                      if (hasFile)
                        const PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new,
                                  color: Colors.green, size: 20),
                              SizedBox(width: 12),
                              Text('Ouvrir'),
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
}
