import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({Key? key}) : super(key: key);

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final db = await _dbService.database;
    var res = await db.query('subjects');
    setState(() {
      _subjects = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المواد الدراسية'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: _subjects.length,
        itemBuilder: (context, index) {
          var sub = _subjects[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.book, color: Colors.blue),
              ),
              title: Text('${sub['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('رمز المادة: ${sub['code']} | الحصص الأسبوعية: ${sub['weekly_periods_count']}'),
            ),
          );
        },
      ),
    );
  }
}
