import 'package:flutter/material.dart';
import '../../services/pdf_report_service.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final PdfReportService pdfService = PdfReportService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير وطباعة الجدول'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
                title: const Text('الجدول الأسبوعي الشامل لجميع الصفوف والشعب', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('تصدير مستند PDF جاهز للطباعة يحتوي كافة الصفوف والشعب'),
                trailing: ElevatedButton(
                  child: const Text('تصدير PDF'),
                  onPressed: () async {
                    String path = await pdfService.generateComprehensivePdfReport(1);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم تصدير ملف PDF بنجاح في المسار: \$path')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
