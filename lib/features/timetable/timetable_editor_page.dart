import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class TimetableEditorPage extends StatefulWidget {
  const TimetableEditorPage({Key? key}) : super(key: key);

  @override
  State<TimetableEditorPage> createState() => _TimetableEditorPageState();
}

class _TimetableEditorPageState extends State<TimetableEditorPage> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _sections = [];
  int? _selectedSectionId;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final db = await _dbService.database;
    var res = await db.query('sections');
    setState(() {
      _sections = res;
      if (res.isNotEmpty) _selectedSectionId = res.first['id'];
    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    List<String> periods = ['الحصة 1', 'الحصة 2', 'الحصة 3', 'الحصة 4', 'الحصة 5'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('محرر الجدول المدرسي التفاعلي'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text('اختر الشعبة: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _selectedSectionId,
                  items: _sections.map((s) {
                    return DropdownMenuItem<int>(
                      value: s['id'],
                      child: Text('شعبة \${s['name']}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSectionId = val;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columns: [
                    const DataColumn(label: Text('اليوم / الحصة', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...periods.map((p) => DataColumn(label: Text(p, style: const TextStyle(fontWeight: FontWeight.bold)))),
                  ],
                  rows: days.map((day) {
                    return DataRow(
                      cells: [
                        DataCell(Text(day, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ...periods.map((_) => DataCell(
                          Container(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('الرياضيات', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('أ. أحمد', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعديل الحصة الدراسية...')));
                          },
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
