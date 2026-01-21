import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../database.dart';

class LockedArchivesPage extends StatefulWidget {
  const LockedArchivesPage({Key? key}) : super(key: key);

  @override
  State<LockedArchivesPage> createState() => _LockedArchivesPageState();
}

class _LockedArchivesPageState extends State<LockedArchivesPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _lockedArchives = [];
  Map<String, dynamic>? _selectedArchive;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;
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
    _checkAuthentication();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    setState(() => _isLoading = true);

    final hasPassword =
        await DatabaseHelper.instance.lockedArchivesPasswordExists();

    if (!hasPassword) {
      // Premier accès - définir le mot de passe
      final created = await _showCreatePasswordDialog();
      if (!created) {
        // L'utilisateur a annulé
        if (mounted) Navigator.of(context).pop();
        return;
      }
    } else {
      // Demander le mot de passe
      final authenticated = await _showGlobalUnlockDialog();
      if (!authenticated) {
        // Mot de passe incorrect ou annulé
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    setState(() {
      _isAuthenticated = true;
    });

    _loadLockedArchives();
  }

  Future<bool> _showCreatePasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.security, color: Colors.orange[700]),
              const SizedBox(width: 12),
              const Text('Mot de passe des archives'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Définissez le mot de passe pour accéder aux archives verrouillées',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe *',
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
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_clock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                    ),
                  ),
                  onSubmitted: (_) async {
                    await _processCreatePassword(
                      context,
                      passwordController.text,
                      confirmPasswordController.text,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
              ),
              onPressed: () async {
                await _processCreatePassword(
                  context,
                  passwordController.text,
                  confirmPasswordController.text,
                );
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  Future<void> _processCreatePassword(
    BuildContext context,
    String password,
    String confirmPassword,
  ) async {
    if (password.trim().isEmpty || confirmPassword.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tous les champs sont obligatoires')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le mot de passe doit contenir au moins 4 caractères'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await DatabaseHelper.instance.createLockedArchivesPassword(password);
      if (!context.mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe créé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showGlobalUnlockDialog() async {
    final passwordController = TextEditingController();
    bool obscureText = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_open, color: Colors.orange[700]),
              const SizedBox(width: 12),
              const Text('Accès aux archives verrouillées'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Entrez le mot de passe pour accéder aux archives verrouillées',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
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
                      .verifyLockedArchivesPassword(passwordController.text);
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
              ),
              onPressed: () async {
                final isValid = await DatabaseHelper.instance
                    .verifyLockedArchivesPassword(passwordController.text);
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

  Future<void> _loadLockedArchives() async {
    setState(() => _isLoading = true);
    final archives = await DatabaseHelper.instance.getLockedArchives();
    setState(() {
      _lockedArchives = archives;
      _isLoading = false;
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

  Future<void> _selectArchive(Map<String, dynamic> archive) async {
    // Toujours demander le mot de passe individuel de l'archive
    final unlocked = await _showUnlockDialog(archive);
    if (!unlocked) return;

    setState(() {
      _selectedArchive = archive;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadDocuments(archive['id']);
  }

  Future<bool> _showUnlockDialog(Map<String, dynamic> archive) async {
    final passwordController = TextEditingController();
    bool obscureText = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_open, color: Colors.blue[700]),
              const SizedBox(width: 12),
              const Text('Déverrouiller l\'archive'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Archive: ${archive['name']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Compartiment: ${archive['compartment_name']}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscureText,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe de l\'archive',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
              ),
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

  void _goBack() {
    setState(() {
      _selectedArchive = null;
      _documents = [];
      _searchQuery = '';
      _searchController.clear();
    });
    _animationController.forward(from: 0);
  }

  List<Map<String, dynamic>> get _filteredArchives {
    if (_searchQuery.isEmpty) return _lockedArchives;
    return _lockedArchives.where((arc) {
      final name = (arc['name'] as String).toLowerCase();
      final subtitle = ((arc['subtitle'] as String?) ?? '').toLowerCase();
      final compartmentName =
          ((arc['compartment_name'] as String?) ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          subtitle.contains(query) ||
          compartmentName.contains(query);
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

  Future<void> _showChangeGlobalPasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key, color: Colors.blue),
              SizedBox(width: 12),
              Text('Changer le mot de passe global'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Modification du mot de passe d\'accès aux archives verrouillées',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe actuel *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureCurrent = !obscureCurrent;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureNew = !obscureNew;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_clock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                    ),
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
                if (currentPasswordController.text.trim().isEmpty ||
                    newPasswordController.text.trim().isEmpty ||
                    confirmPasswordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Tous les champs sont obligatoires')),
                  );
                  return;
                }

                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Les nouveaux mots de passe ne correspondent pas')),
                  );
                  return;
                }

                // Vérifier le mot de passe actuel
                final isValid = await DatabaseHelper.instance
                    .verifyLockedArchivesPassword(
                        currentPasswordController.text);

                if (!isValid) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mot de passe actuel incorrect'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await DatabaseHelper.instance.changeLockedArchivesPassword(
                    newPasswordController.text.trim(),
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mot de passe modifié avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Changer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateArchiveDialog() async {
    final nameController = TextEditingController();
    final subtitleController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    int? selectedCompartmentId;
    List<Map<String, dynamic>> compartments = [];
    bool obscurePassword = true;
    bool obscureConfirm = true;

    // Charger les compartiments
    compartments = await DatabaseHelper.instance.getCompartments();

    if (compartments.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord créer un compartiment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.create_new_folder, color: Colors.orange),
              SizedBox(width: 12),
              Text('Créer une archive verrouillée'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedCompartmentId,
                  decoration: const InputDecoration(
                    labelText: 'Compartiment *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder),
                  ),
                  items: compartments.map((comp) {
                    return DropdownMenuItem<int>(
                      value: comp['id'],
                      child: Text(comp['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCompartmentId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l\'archive *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                    hintText: 'Ex: Documents confidentiels',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subtitleController,
                  decoration: const InputDecoration(
                    labelText: 'Sous-titre (optionnel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    hintText: 'Ex: Contrats 2024',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Définissez un mot de passe spécifique pour cette archive',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_clock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                    ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
              ),
              onPressed: () async {
                if (selectedCompartmentId == null ||
                    nameController.text.trim().isEmpty ||
                    passwordController.text.trim().isEmpty ||
                    confirmPasswordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Veuillez remplir tous les champs obligatoires'),
                    ),
                  );
                  return;
                }

                if (passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Les mots de passe ne correspondent pas'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (passwordController.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Le mot de passe doit contenir au moins 4 caractères'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await DatabaseHelper.instance.createArchive(
                    selectedCompartmentId!,
                    nameController.text.trim(),
                    subtitleController.text.trim().isEmpty
                        ? null
                        : subtitleController.text.trim(),
                    isLocked: true,
                    password: passwordController.text.trim(),
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _loadLockedArchives();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Archive verrouillée créée avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    final filePath = document['file_path'] as String?;

    if (filePath == null || filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce document n\'a pas de fichier associé'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le fichier n\'existe plus'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Importer le package url_launcher
      // Pour Windows/Linux/macOS, on utilise la commande système
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ouverture de ${document['name']}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir le fichier: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showChangePasswordDialog(Map<String, dynamic> archive) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key, color: Colors.blue),
              SizedBox(width: 12),
              Text('Changer le mot de passe'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe actuel *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureCurrent = !obscureCurrent;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureNew = !obscureNew;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_clock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                    ),
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
                if (currentPasswordController.text.trim().isEmpty ||
                    newPasswordController.text.trim().isEmpty ||
                    confirmPasswordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Tous les champs sont obligatoires')),
                  );
                  return;
                }

                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Les nouveaux mots de passe ne correspondent pas')),
                  );
                  return;
                }

                // Vérifier le mot de passe actuel
                final isValid = await DatabaseHelper.instance
                    .verifyArchivePassword(
                        archive['id'], currentPasswordController.text);

                if (!isValid) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mot de passe actuel incorrect'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await DatabaseHelper.instance.changeArchivePassword(
                    archive['id'],
                    newPasswordController.text.trim(),
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mot de passe modifié avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Changer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDocumentDialog() async {
    if (_selectedArchive == null) return;

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
                    hintText: 'Ex: Rapport confidentiel',
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
                    _selectedArchive!['id'],
                    nameController.text.trim(),
                    finalFilePath,
                    fileType,
                  );

                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadDocuments(_selectedArchive!['id']);
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

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_selectedArchive != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBack,
            ),
          Icon(Icons.lock, size: 20, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Text(
            'Archives Verrouillées',
            style: TextStyle(
              fontWeight: _selectedArchive == null
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _selectedArchive == null
                  ? Colors.orange[700]
                  : Colors.grey[700],
            ),
          ),
          if (_selectedArchive != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Icon(Icons.folder, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              _selectedArchive!['compartment_name'] ?? '',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Icon(Icons.lock_open, size: 16, color: Colors.orange[700]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _selectedArchive!['name'],
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.lock, size: 24),
            const SizedBox(width: 12),
            Text(
              _selectedArchive != null
                  ? 'Documents Confidentiels'
                  : 'Archives Verrouillées',
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
            icon: const Icon(Icons.vpn_key),
            onPressed: _showChangeGlobalPasswordDialog,
            tooltip: 'Changer le mot de passe global',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedArchive != null) {
                _loadDocuments(_selectedArchive!['id']);
              } else {
                _loadLockedArchives();
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
                  : _buildArchivesGrid(),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedArchive != null
          ? FloatingActionButton.extended(
              onPressed: _showAddDocumentDialog,
              backgroundColor: Colors.orange[700],
              icon: const Icon(Icons.add),
              label: const Text('Document'),
            )
          : FloatingActionButton.extended(
              onPressed: _showCreateArchiveDialog,
              backgroundColor: Colors.orange[700],
              icon: const Icon(Icons.add),
              label: const Text('Archive'),
            ),
    );
  }

  Widget _buildArchivesGrid() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_filteredArchives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Aucune archive verrouillée',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Les archives protégées apparaîtront ici',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
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
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange[400]!,
                                Colors.orange[600]!
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.lock,
                              size: 48, color: Colors.white),
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
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            archive['compartment_name'] ?? '',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      if (value == 'change_password') {
                        _showChangePasswordDialog(archive);
                      } else if (value == 'delete') {
                        _confirmDeleteArchive(archive);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'change_password',
                        child: Row(
                          children: [
                            Icon(Icons.vpn_key, color: Colors.blue, size: 20),
                            SizedBox(width: 12),
                            Text('Changer le mot de passe'),
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
                  onTap: () => _openDocument(document),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.shield,
                              size: 40, color: Colors.red[700]),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock,
                                    size: 8, color: Colors.orange[700]),
                                const SizedBox(width: 2),
                                Text(
                                  document['file_type']?.toUpperCase() ?? '',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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

  void _confirmDeleteArchive(Map<String, dynamic> archive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cette action supprimera l\'archive et tous ses documents',
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
        _loadLockedArchives();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voulez-vous vraiment supprimer le document "${document['name']}" ?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ce document confidentiel sera définitivement supprimé',
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