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
    // Initialiser sqflite_ffi pour desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Obtenir le chemin du répertoire des documents
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    _databasePath = join(appDocDir.path, 'ArchiveManager', filePath);
    
    // Créer le répertoire s'il n'existe pas
    final dir = Directory(dirname(_databasePath!));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return await openDatabase(
      _databasePath!,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Création des tables de la base de données
  Future<void> _createDB(Database db, int version) async {
    // Table des utilisateurs (mot de passe)
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

    // Table des archives
    await db.execute('''
      CREATE TABLE archives (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        compartment_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        subtitle TEXT,
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

  /// Vérifier le mot de passe
  Future<bool> verifyPassword(String password) async {
    final db = await database;
    final result = await db.query('users', limit: 1);
    if (result.isEmpty) return false;
    
    final storedHash = result.first['password_hash'] as String;
    return storedHash == _hashPassword(password);
  }

  /// Changer le mot de passe
  Future<void> changePassword(String newPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password_hash': _hashPassword(newPassword)},
      where: 'id = (SELECT MIN(id) FROM users)',
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
  Future<void> updateCompartment(int id, String name, String? description) async {
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
  Future<int> createArchive(int compartmentId, String name, String? subtitle) async {
    final db = await database;
    return await db.insert('archives', {
      'compartment_id': compartmentId,
      'name': name,
      'subtitle': subtitle,
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

  /// Mettre à jour une archive
  Future<void> updateArchive(int id, String name, String? subtitle) async {
    final db = await database;
    await db.update(
      'archives',
      {'name': name, 'subtitle': subtitle},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprimer une archive
  Future<void> deleteArchive(int id) async {
    final db = await database;
    await db.delete('archives', where: 'id = ?', whereArgs: [id]);
  }

  // ========== GESTION DES DOCUMENTS ==========

  /// Ajouter un document
  Future<int> addDocument(int archiveId, String name, String filePath, String? fileType) async {
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
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // ========== UTILITAIRES ==========

  /// Exporter la base de données
  Future<String> exportDatabase() async {
    await database;
    final backupDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = join(backupDir.path, 'ArchiveManager', 'backup_$timestamp.db');
    
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