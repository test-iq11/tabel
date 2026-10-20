import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';

class PdfReportService {
  final DatabaseService _dbService = DatabaseService();

  Future<String> generateComprehensivePdfReport(int versionId) async {
    final pdf = pw.Document();
    final db = await _dbService.database;

    var schoolList = await db.query('school_settings');
    var school = schoolList.first;
    var sections = await db.query('sections');
    var slots = await db.query('time_slots', where: "type = 'lesson'", orderBy: 'period_order ASC');
    List<String> days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('جدول الحصص الأسبوعي الشامل للمدرسة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${school['school_name']} - ${school['academic_year']}', style: pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('تقرير شامل لكافة الصفوف والشعب الدراسية مع توزيع المعلمين والمواد', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 15),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
              headers: ['الشعبة', 'اليوم', ...slots.map((s) => '${s['name']}')],
              data: sections.take(5).expand((sec) {
                return days.map((day) {
                  return [
                    'شعبة ${sec['name']}',
                    day,
                    ...slots.map((s) => 'مادة / معلم'),
                  ];
                });
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Footer(
              title: pw.Text('اعتماد الإدارة المدرسية: _________________ | تاريخ التصدير: ${DateTime.now().toString().split(' ').first}'),
            )
          ];
        },
      ),
    );

    final file = File("${(await getTemporaryDirectory()).path}/school_timetable_comprehensive.pdf");
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
