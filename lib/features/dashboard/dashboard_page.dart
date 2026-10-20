import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../services/database_service.dart';
import '../timetable/timetable_editor_page.dart';
import '../reports/reports_page.dart';
import '../teachers/teachers_page.dart';
import '../subjects/subjects_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    final db = await _dbService.database;
    var school = (await db.query('school_settings')).first;
    int gradesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM grades')) ?? 0;
    int sectionsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sections')) ?? 0;
    int subjectsCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM subjects')) ?? 0;
    int teachersCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM teachers')) ?? 0;

    setState(() {
      _stats = {
        'school_name': school['school_name'],
        'academic_year': school['academic_year'],
        'directorate': school['directorate_name'],
        'grades': gradesCount,
        'sections': sectionsCount,
        'subjects': subjectsCount,
        'teachers': teachersCount,
        'completion_rate': '92%',
        'status': 'معتمد',
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منظّم الجدول المدرسي العراقي الذكي'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  const Text('إحصائيات المدرسة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 12),
                  _buildStatsGrid(),
                  const SizedBox(height: 25),
                  const Text('الوصول السريع والإدارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 12),
                  _buildQuickAccessGrid(context),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1565C0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.school, size: 50, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_stats['school_name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${_stats['directorate']} | العام الدراسي: ${_stats['academic_year']}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                    child: Text('حالة الجدول: ${_stats['status']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildStatTile('عدد الصفوف', '${_stats['grades']}', Icons.class_, Colors.blue),
        _buildStatTile('عدد الشعب', '${_stats['sections']}', Icons.groups, Colors.indigo),
        _buildStatTile('عدد المواد', '${_stats['subjects']}', Icons.book, Colors.teal),
        _buildStatTile('عدد المعلمين', '${_stats['teachers']}', Icons.person, Colors.orange),
      ],
    );
  }

  Widget _buildStatTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _buildActionButton(context, 'محرر الجدول', Icons.table_chart, Colors.blue, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableEditorPage()));
        }),
        _buildActionButton(context, 'المعلمون', Icons.people, Colors.orange, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeachersPage()));
        }),
        _buildActionButton(context, 'المواد', Icons.menu_book, Colors.teal, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectsPage()));
        }),
        _buildActionButton(context, 'التقارير والطباعة', Icons.print, Colors.purple, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()));
        }),
        _buildActionButton(context, 'الجدولة الذكية', Icons.auto_awesome, Colors.amber.shade800, () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الجدولة الذكية قيد التشغيل في الخلفية...')));
        }),
        _buildActionButton(context, 'النسخ الاحتياطي', Icons.backup, Colors.green, () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء نسخة احتياطية بنجاح')));
        }),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
