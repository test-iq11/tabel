import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({Key? key}) : super(key: key);

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final db = await _dbService.database;
    var res = await db.query('teachers');
    setState(() {
      _teachers = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المعلمين والنصاب'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: _teachers.length,
        itemBuilder: (context, index) {
          var t = _teachers[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('${t['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('الرمز: ${t['code']} | النصاب المستهدف: ${t['target_weekly_quota']} حصة'),
              trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {}),
            ),
          );
        },
      ),
    );
  }
}
