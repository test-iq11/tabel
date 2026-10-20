import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// تقارير PDF قابلة للطباعة. يستخدم خط النظام العربي على Android أو خطاً يضيفه المطور إلى assets/fonts.
class PdfReportService {
  Future<pw.Font> _arabicFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Arabic-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      // يحتوي Android عادةً على خط Noto Naskh Arabic ضمن خطوط النظام.
      const candidates = [
        '/system/fonts/NotoNaskhArabic-Regular.ttf',
        '/system/fonts/NotoNaskhArabicUI-Regular.ttf',
        '/system/fonts/NotoSansArabic-Regular.ttf',
      ];
      for (final path in candidates) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return pw.Font.ttf(ByteData.sublistView(bytes));
        }
      }
      throw StateError('لم يتم العثور على خط عربي يدعم PDF. أضف ملفاً مرخصاً باسم assets/fonts/Arabic-Regular.ttf ثم أعد بناء التطبيق.');
    }
  }

  Future<Uint8List> buildTimetablePdf({
    required String schoolName,
    required String academicYear,
    required String versionName,
    required String status,
    required List<Map<String, Object?>> entries,
    String title = 'الجدول الأسبوعي الشامل لجميع الصفوف والشعب',
    PdfPageFormat pageFormat = PdfPageFormat.a3,
  }) async {
    final font = await _arabicFont();
    final pdf = pw.Document();
    final sorted = [...entries]..sort((a, b) {
      final day = _num(a['day_position']).compareTo(_num(b['day_position']));
      if (day != 0) return day;
      final slot = _num(a['slot_position']).compareTo(_num(b['slot_position']));
      if (slot != 0) return slot;
      return '${a['grade_name']} ${a['section_name']}'.compareTo('${b['grade_name']} ${b['section_name']}');
    });
    final data = <List<String>>[
      ['اليوم', 'الفترة', 'الوقت', 'الصف والشعبة', 'المادة', 'المعلم'],
      ...sorted.map((entry) => [
        '${entry['day_name'] ?? ''}', '${entry['slot_name'] ?? ''}',
        '${entry['start_time'] ?? ''} - ${entry['end_time'] ?? ''}',
        '${entry['grade_name'] ?? ''} / ${entry['section_name'] ?? ''}',
        '${entry['subject_name'] ?? ''}', '${entry['teacher_name'] ?? 'غير مسند'}',
      ]),
    ];
    final theme = pw.ThemeData.withFont(base: font, bold: font);
    pdf.addPage(pw.MultiPage(
      pageFormat: pageFormat,
      theme: theme,
      margin: const pw.EdgeInsets.all(22),
      header: (context) => pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(children: [
        pw.Text(schoolName, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.Text('العام الدراسي: $academicYear  |  النسخة: $versionName  |  الحالة: $status', style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(),
      ])),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Text('تاريخ التقرير: ${DateTime.now().toIso8601String().split('T').first}  •  صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (context) => [
        if (sorted.isEmpty)
          pw.Padding(padding: const pw.EdgeInsets.all(18), child: pw.Text('لا توجد حصص محفوظة في النسخة المختارة.'))
        else
          pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.TableHelper.fromTextArray(
            context: context,
            data: data,
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF183B66)),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F6FA)),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            cellAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.9), 1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.1), 3: const pw.FlexColumnWidth(1.7),
              4: const pw.FlexColumnWidth(1.5), 5: const pw.FlexColumnWidth(1.4),
            },
          )),
      ],
    ));
    return pdf.save();
  }

  Future<String?> savePdf(Uint8List bytes, {String fileName = 'الجدول-المدرسي.pdf'}) async {
    return FilePicker.platform.saveFile(
      dialogTitle: 'حفظ تقرير PDF', fileName: fileName,
      type: FileType.custom, allowedExtensions: ['pdf'], bytes: bytes,
    );
  }

  Future<void> preview(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  int _num(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
