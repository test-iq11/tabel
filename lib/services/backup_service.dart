import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database_service.dart';

class BackupService {
  BackupService(this._db);
  final DatabaseService _db;

  Future<String?> exportBackup() async {
    final data = await _db.exportAll();
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: 'نسخة-المدرسة-$stamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return path;
  }

  Future<Map<String, Object?>?> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختيار ملف النسخة الاحتياطية',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.single;
    final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw const FormatException('تعذر قراءة الملف المحدد.');
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('محتوى ملف النسخة الاحتياطية غير صالح.');
    final backup = decoded.cast<String, Object?>();
    if (backup['format'] != 'iraqi_school_timetable_backup') {
      throw const FormatException('هذا الملف ليس نسخة احتياطية صادرة من التطبيق.');
    }
    // حفظ نسخة طوارئ محلية قبل استبدال قاعدة البيانات الحالية.
    final before = await _db.exportAll();
    final docs = await getApplicationDocumentsDirectory();
    final emergency = File(p.join(docs.path, 'قبل-الاستعادة-${DateTime.now().millisecondsSinceEpoch}.json'));
    await emergency.writeAsString(const JsonEncoder.withIndent('  ').convert(before), flush: true);
    await _db.importAll(backup);
    final tables = (backup['tables'] as Map).cast<String, dynamic>();
    return {
      'path': file.path ?? file.name,
      'emergency_backup': emergency.path,
      'school_name': ((tables['school_settings'] as List).isNotEmpty)
          ? (tables['school_settings'] as List).first['school_name'] : 'غير معروف',
      'sections': (tables['sections'] as List).length,
      'teachers': (tables['teachers'] as List).length,
      'subjects': (tables['subjects'] as List).length,
      'entries': (tables['timetable_entries'] as List).length,
    };
  }
}
