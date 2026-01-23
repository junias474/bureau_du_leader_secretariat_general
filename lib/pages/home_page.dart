import 'package:flutter/material.dart';
import 'compartments_page.dart';
import 'locked_archives_page.dart';
import 'settings_page.dart';
import 'search_page.dart';
import 'reports_page.dart';
import 'about_page.dart';
import 'data_visualization.dart'; // NOUVEAU: Import de la page de visualisation
import '../database.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const CompartmentsPage(),
    const LockedArchivesPage(),
    const DataVisualizationPage(), // NOUVEAU: Page de visualisation des données
    const SearchPage(),
    const ReportsPage(),
    const SettingsPage(),
    const AboutPage(),
  ];

  final List<_NavigationItem> _navItems = [
    _NavigationItem(Icons.dashboard, 'Tableau de bord'),
    _NavigationItem(Icons.folder, 'Mes Archives'),
    _NavigationItem(Icons.lock, 'Archives Verrouillées'),
    _NavigationItem(Icons.table_chart, 'Données'), // NOUVEAU: Option de menu
    _NavigationItem(Icons.search, 'Rechercher'),
    _NavigationItem(Icons.assessment, 'Rapports'),
    _NavigationItem(Icons.settings, 'Paramètres'),
    _NavigationItem(Icons.info, 'À propos'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue[800]!, Colors.blue[900]!],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Logo personnalisé avec conteneur circulaire blanc
                      Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Gestionnaire d\'Archives',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Département de la Communication',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'CMCI',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _navItems.length,
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final isSelected = _selectedIndex == index;
                      final isLockedArchives =
                          index == 2; // Archives Verrouillées
                      final isDataVisualization =
                          index == 3; // NOUVEAU: Données

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = index),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isLockedArchives
                                        ? Colors.orange.withOpacity(0.2)
                                        : isDataVisualization
                                            ? Colors.purple.withOpacity(0.2)
                                            : Colors.white.withOpacity(0.15))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: isLockedArchives
                                            ? Colors.orange.withOpacity(0.5)
                                            : isDataVisualization
                                                ? Colors.purple.withOpacity(0.5)
                                                : Colors.white.withOpacity(0.3),
                                        width: 1)
                                    : null,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  item.icon,
                                  color: isSelected
                                      ? (isLockedArchives
                                          ? Colors.orange[300]
                                          : isDataVisualization
                                              ? Colors.purple[300]
                                              : Colors.white)
                                      : Colors.white70,
                                  size: 22,
                                ),
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? (isLockedArchives
                                            ? Colors.orange[200]
                                            : isDataVisualization
                                                ? Colors.purple[200]
                                                : Colors.white)
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: isLockedArchives
                                    ? Icon(
                                        Icons.shield,
                                        size: 16,
                                        color: isSelected
                                            ? Colors.orange[300]
                                            : Colors.white54,
                                      )
                                    : isDataVisualization
                                        ? Icon(
                                            Icons.bar_chart,
                                            size: 16,
                                            color: isSelected
                                                ? Colors.purple[300]
                                                : Colors.white54,
                                          )
                                        : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: Color.fromARGB(167, 255, 255, 255),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String label;

  _NavigationItem(this.icon, this.label);
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _totalCompartments = 0;
  int _totalArchives = 0;
  int _totalLockedArchives = 0;
  int _totalDocuments = 0;
  List<Map<String, dynamic>> _recentDocuments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      final compResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM compartments');
      _totalCompartments = compResult.first['count'] as int;

      final arcResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM archives');
      _totalArchives = arcResult.first['count'] as int;

      final lockedResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM archives WHERE is_locked = 1');
      _totalLockedArchives = lockedResult.first['count'] as int;

      final docResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM documents');
      _totalDocuments = docResult.first['count'] as int;

      final recentDocs = await db.rawQuery('''
        SELECT d.name, d.added_at, a.name as archive_name, 
               a.is_locked, c.name as compartment_name
        FROM documents d
        JOIN archives a ON d.archive_id = a.id
        JOIN compartments c ON a.compartment_id = c.id
        ORDER BY d.added_at DESC
        LIMIT 5
      ''');

      setState(() {
        _recentDocuments = recentDocs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tableau de bord'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.folder,
                            title: 'Compartiments',
                            value: _totalCompartments.toString(),
                            color: Colors.blue,
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.blue[600]!],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.archive,
                            title: 'Archives',
                            value: _totalArchives.toString(),
                            color: Colors.green,
                            gradient: LinearGradient(
                              colors: [Colors.green[400]!, Colors.green[600]!],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.lock,
                            title: 'Archives Verrouillées',
                            value: _totalLockedArchives.toString(),
                            color: Colors.orange,
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange[400]!,
                                Colors.orange[600]!
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.description,
                            title: 'Documents',
                            value: _totalDocuments.toString(),
                            color: Colors.purple,
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple[400]!,
                                Colors.purple[600]!
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Ajouts récents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _recentDocuments.isEmpty
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox,
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Aucun document récent',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Card(
                            elevation: 2,
                            child: Column(
                              children: _recentDocuments.map((doc) {
                                final isLocked = doc['is_locked'] == 1;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isLocked
                                        ? Colors.orange[100]
                                        : Colors.blue[100],
                                    child: Icon(
                                      isLocked
                                          ? Icons.shield
                                          : Icons.description,
                                      color: isLocked
                                          ? Colors.orange[700]
                                          : Colors.blue[700],
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      if (isLocked) ...[
                                        Icon(Icons.lock,
                                            size: 14,
                                            color: Colors.orange[700]),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          doc['name'] as String,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${doc['compartment_name']} > ${doc['archive_name']}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  trailing: Text(
                                    _formatDate(doc['added_at'] as String),
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[500]),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Aujourd\'hui';
      } else if (difference.inDays == 1) {
        return 'Hier';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays} jours';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final Gradient gradient;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
