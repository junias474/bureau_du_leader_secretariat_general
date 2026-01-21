import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Classe singleton pour gérer la base de données SQLite
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _databasePath;

  DatabaseHelper._init();

  /// Getter pour obtenir l'instance de la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('archives.db');
    return _database!;
  }

  /// Initialisation de la base de données
  Future<Database> _initDB(String filePath) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    _databasePath = join(appDocDir.path, 'ArchiveManager', filePath);

    final dir = Directory(dirname(_databasePath!));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return await openDatabase(
      _databasePath!,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Création des tables de la base de données
  Future<void> _createDB(Database db, int version) async {
    // Table des utilisateurs (mot de passe principal)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Table des compartiments (classeurs)
    await db.execute('''
      CREATE TABLE compartments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Table des archives avec support de verrouillage
    await db.execute('''
      CREATE TABLE archives (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        compartment_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        subtitle TEXT,
        is_locked INTEGER DEFAULT 0,
        password_hash TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (compartment_id) REFERENCES compartments (id) ON DELETE CASCADE
      )
    ''');

    // Table des documents
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        archive_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_type TEXT,
        added_at TEXT NOT NULL,
        FOREIGN KEY (archive_id) REFERENCES archives (id) ON DELETE CASCADE
      )
    ''');

    // Table pour le mot de passe global des archives verrouillées
    await db.execute('''
      CREATE TABLE locked_archives_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Mise à niveau de la base de données
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ajouter les colonnes pour le verrouillage si elles n'existent pas
      await db.execute(
          'ALTER TABLE archives ADD COLUMN is_locked INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE archives ADD COLUMN password_hash TEXT');
    }

    if (oldVersion < 3) {
      // Ajouter la table pour le mot de passe global des archives verrouillées
      await db.execute('''
        CREATE TABLE IF NOT EXISTS locked_archives_settings (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          password_hash TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  // ========== GESTION DES UTILISATEURS ==========

  /// Hasher un mot de passe avec SHA-256
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Vérifier si un utilisateur existe
  Future<bool> userExists() async {
    final db = await database;
    final result = await db.query('users', limit: 1);
    return result.isNotEmpty;
  }

  /// Créer un utilisateur (premier lancement)
  Future<void> createUser(String password) async {
    final db = await database;
    await db.insert('users', {
      'password_hash': _hashPassword(password),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Vérifier le mot de passe principal
  Future<bool> verifyPassword(String password) async {
    final db = await database;
    final result = await db.query('users', limit: 1);
    if (result.isEmpty) return false;

    final storedHash = result.first['password_hash'] as String;
    return storedHash == _hashPassword(password);
  }

  /// Changer le mot de passe principal
  Future<void> changePassword(String newPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password_hash': _hashPassword(newPassword)},
      where: 'id = (SELECT MIN(id) FROM users)',
    );
  }

  // ========== GESTION DU MOT DE PASSE GLOBAL DES ARCHIVES VERROUILLÉES ==========

  /// Vérifier si le mot de passe global des archives verrouillées existe
  Future<bool> lockedArchivesPasswordExists() async {
    final db = await database;
    final result = await db.query('locked_archives_settings', limit: 1);
    return result.isNotEmpty;
  }

  /// Créer le mot de passe global des archives verrouillées
  Future<void> createLockedArchivesPassword(String password) async {
    final db = await database;
    await db.insert('locked_archives_settings', {
      'id': 1,
      'password_hash': _hashPassword(password),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Vérifier le mot de passe global des archives verrouillées
  Future<bool> verifyLockedArchivesPassword(String password) async {
    final db = await database;
    final result = await db.query('locked_archives_settings', limit: 1);
    if (result.isEmpty) return false;

    final storedHash = result.first['password_hash'] as String;
    return storedHash == _hashPassword(password);
  }

  /// Changer le mot de passe global des archives verrouillées
  Future<void> changeLockedArchivesPassword(String newPassword) async {
    final db = await database;
    await db.update(
      'locked_archives_settings',
      {'password_hash': _hashPassword(newPassword)},
      where: 'id = 1',
    );
  }

  // ========== GESTION DES COMPARTIMENTS ==========

  /// Créer un compartiment
  Future<int> createCompartment(String name, String? description) async {
    final db = await database;
    return await db.insert('compartments', {
      'name': name,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Obtenir tous les compartiments
  Future<List<Map<String, dynamic>>> getCompartments() async {
    final db = await database;
    return await db.query('compartments', orderBy: 'name ASC');
  }

  /// Mettre à jour un compartiment
  Future<void> updateCompartment(
      int id, String name, String? description) async {
    final db = await database;
    await db.update(
      'compartments',
      {'name': name, 'description': description},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprimer un compartiment
  Future<void> deleteCompartment(int id) async {
    final db = await database;
    await db.delete('compartments', where: 'id = ?', whereArgs: [id]);
  }

  // ========== GESTION DES ARCHIVES ==========

  /// Créer une archive
  Future<int> createArchive(int compartmentId, String name, String? subtitle,
      {bool isLocked = false, String? password}) async {
    final db = await database;
    return await db.insert('archives', {
      'compartment_id': compartmentId,
      'name': name,
      'subtitle': subtitle,
      'is_locked': isLocked ? 1 : 0,
      'password_hash':
          isLocked && password != null ? _hashPassword(password) : null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Obtenir les archives d'un compartiment
  Future<List<Map<String, dynamic>>> getArchives(int compartmentId) async {
    final db = await database;
    return await db.query(
      'archives',
      where: 'compartment_id = ?',
      whereArgs: [compartmentId],
      orderBy: 'name ASC',
    );
  }

  /// Obtenir toutes les archives verrouillées
  Future<List<Map<String, dynamic>>> getLockedArchives() async {
    final db = await database;
    final archives = await db.rawQuery('''
      SELECT a.*, c.name as compartment_name
      FROM archives a
      JOIN compartments c ON a.compartment_id = c.id
      WHERE a.is_locked = 1
      ORDER BY a.name ASC
    ''');
    return archives;
  }

  /// Mettre à jour une archive
  Future<void> updateArchive(int id, String name, String? subtitle,
      {bool? isLocked, String? password}) async {
    final db = await database;
    final Map<String, dynamic> data = {
      'name': name,
      'subtitle': subtitle,
    };

    if (isLocked != null) {
      data['is_locked'] = isLocked ? 1 : 0;
      if (isLocked && password != null) {
        data['password_hash'] = _hashPassword(password);
      } else if (!isLocked) {
        data['password_hash'] = null;
      }
    }

    await db.update(
      'archives',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Vérifier le mot de passe d'une archive verrouillée
  Future<bool> verifyArchivePassword(int archiveId, String password) async {
    final db = await database;
    final result = await db.query(
      'archives',
      where: 'id = ? AND is_locked = 1',
      whereArgs: [archiveId],
      limit: 1,
    );

    if (result.isEmpty) return false;

    final storedHash = result.first['password_hash'] as String?;
    if (storedHash == null) return false;

    return storedHash == _hashPassword(password);
  }

  /// Changer le mot de passe d'une archive verrouillée
  Future<void> changeArchivePassword(int archiveId, String newPassword) async {
    final db = await database;
    await db.update(
      'archives',
      {'password_hash': _hashPassword(newPassword)},
      where: 'id = ? AND is_locked = 1',
      whereArgs: [archiveId],
    );
  }

  /// Supprimer une archive
  Future<void> deleteArchive(int id) async {
    final db = await database;
    await db.delete('archives', where: 'id = ?', whereArgs: [id]);
  }

  // ========== GESTION DES DOCUMENTS ==========

  /// Ajouter un document
  Future<int> addDocument(
      int archiveId, String name, String filePath, String? fileType) async {
    final db = await database;
    return await db.insert('documents', {
      'archive_id': archiveId,
      'name': name,
      'file_path': filePath,
      'file_type': fileType,
      'added_at': DateTime.now().toIso8601String(),
    });
  }

  /// Obtenir les documents d'une archive
  Future<List<Map<String, dynamic>>> getDocuments(int archiveId) async {
    final db = await database;
    return await db.query(
      'documents',
      where: 'archive_id = ?',
      whereArgs: [archiveId],
      orderBy: 'name ASC',
    );
  }

  /// Supprimer un document
  Future<void> deleteDocument(int id) async {
    final db = await database;

    // Récupérer le chemin du fichier avant suppression
    final result = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isNotEmpty) {
      final filePath = result.first['file_path'] as String?;

      // Supprimer de la base de données
      await db.delete('documents', where: 'id = ?', whereArgs: [id]);

      // Supprimer le fichier physique si le chemin existe et n'est pas vide
      if (filePath != null && filePath.isNotEmpty) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('Erreur lors de la suppression du fichier: $e');
        }
      }
    }
  }

  // ========== UTILITAIRES ==========

  /// Exporter la base de données
  Future<String> exportDatabase() async {
    await database;
    final backupDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath =
        join(backupDir.path, 'ArchiveManager', 'backup_$timestamp.db');

    await File(_databasePath!).copy(backupPath);
    return backupPath;
  }

  /// Restaurer la base de données
  Future<void> restoreDatabase(String backupPath) async {
    final db = await database;

    await db.close();
    await File(backupPath).copy(_databasePath!);

    _database = await _initDB('archives.db');
  }

  /// Réinitialiser la base de données
  Future<void> resetDatabase() async {
    final db = await database;

    await db.close();
    await File(_databasePath!).delete();

    _database = await _initDB('archives.db');
  }

  /// Fermer la base de données
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
