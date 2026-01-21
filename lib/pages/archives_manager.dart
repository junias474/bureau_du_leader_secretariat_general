import 'package:flutter/material.dart';
import '../database.dart';

class ArchivesManager extends StatefulWidget {
  final int compartmentId;
  final Function(Map<String, dynamic>) onArchiveSelected;
  final String searchQuery;

  const ArchivesManager({
    Key? key,
    required this.compartmentId,
    required this.onArchiveSelected,
    required this.searchQuery,
  }) : super(key: key);

  @override
  State<ArchivesManager> createState() => ArchivesManagerState();
}

class ArchivesManagerState extends State<ArchivesManager>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _archives = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    loadArchives();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadArchives() async {
    final archives = await DatabaseHelper.instance.getArchives(widget.compartmentId);
    setState(() {
      _archives = archives;
    });
    _animationController.forward(from: 0);
  }

  List<Map<String, dynamic>> get _filteredArchives {
    if (widget.searchQuery.isEmpty) return _archives;
    return _archives.where((arc) {
      final name = (arc['name'] as String).toLowerCase();
      final subtitle = ((arc['subtitle'] as String?) ?? '').toLowerCase();
      final query = widget.searchQuery.toLowerCase();
      return name.contains(query) || subtitle.contains(query);
    }).toList();
  }

  Future<bool> showUnlockDialog(Map<String, dynamic> archive) async {
    final passwordController = TextEditingController();
    bool obscureText = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.orange[700]),
              const SizedBox(width: 12),
              const Text('Archive Verrouillée'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cette archive est protégée par mot de passe.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscureText,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscureText = !obscureText;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) async {
                  final isValid = await DatabaseHelper.instance
                      .verifyArchivePassword(
                          archive['id'], passwordController.text);
                  if (context.mounted) {
                    Navigator.pop(context, isValid);
                    if (!isValid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mot de passe incorrect'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final isValid = await DatabaseHelper.instance
                    .verifyArchivePassword(
                        archive['id'], passwordController.text);
                if (context.mounted) {
                  Navigator.pop(context, isValid);
                  if (!isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mot de passe incorrect'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Déverrouiller'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  Future<void> selectArchive(Map<String, dynamic> archive) async {
    if (archive['is_locked'] == 1) {
      final unlocked = await showUnlockDialog(archive);
      if (!unlocked) return;
    }
    widget.onArchiveSelected(archive);
  }

  void showArchiveDialog({Map<String, dynamic>? archive}) {
    final isEditing = archive != null;
    final nameController = TextEditingController(text: archive?['name'] ?? '');
    final subtitleController =
        TextEditingController(text: archive?['subtitle'] ?? '');
    bool isLocked = archive?['is_locked'] == 1;
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CheckboxListTile(
                    title: const Text('Archive verrouillée'),
                    subtitle: const Text(
                        'Protéger cette archive avec un mot de passe'),
                    value: isLocked,
                    onChanged: (value) {
                      setDialogState(() {
                        isLocked = value ?? false;
                      });
                    },
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe de l\'archive *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
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

                if (isLocked && passwordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Le mot de passe est obligatoire pour une archive verrouillée')),
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
                      isLocked: isLocked,
                      password:
                          isLocked ? passwordController.text.trim() : null,
                    );
                  } else {
                    await DatabaseHelper.instance.createArchive(
                      widget.compartmentId,
                      nameController.text.trim(),
                      subtitleController.text.trim().isEmpty
                          ? null
                          : subtitleController.text.trim(),
                      isLocked: isLocked,
                      password:
                          isLocked ? passwordController.text.trim() : null,
                    );
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  loadArchives();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            isEditing ? 'Archive modifiée' : 'Archive créée')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(isEditing ? 'Modifier' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> confirmDeleteArchive(Map<String, dynamic> archive) async {
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
        loadArchives();
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

  @override
  Widget build(BuildContext context) {
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
        final isLocked = archive['is_locked'] == 1;
        
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                InkWell(
                  onTap: () => selectArchive(archive),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isLocked ? Colors.orange[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isLocked ? Icons.lock : Icons.archive,
                            size: 48,
                            color: isLocked ? Colors.orange[700] : Colors.green[700],
                          ),
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
                if (isLocked)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'VERROUILLÉE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
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
                          size: 20, color: Colors.grey),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      if (value == 'edit') {
                        showArchiveDialog(archive: archive);
                      } else if (value == 'delete') {
                        confirmDeleteArchive(archive);
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
}