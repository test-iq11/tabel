import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/ui_helpers.dart';
import '../../data/database_service.dart';
import '../../services/backup_service.dart';
import '../../services/conflict_detection_service.dart';
import '../../services/pdf_report_service.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({required this.onChanged, super.key});
  final VoidCallback onChanged;
  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  Future<Map<String, Object?>>? _future;
  bool _busy = false;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _future = _load();

  Future<Map<String, Object?>> _load() async {
    final db = DatabaseService.instance;
    final yearId = await db.activeYearId();
    final versionId = await db.activeVersionId(yearId);
    final versions = (await db.rows('timetable_versions')).where((v) => v['academic_year_id'] == yearId).toList()
      ..sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return {
      'settings': await db.getSettings(), 'year': await db.activeYear() ?? <String, Object?>{},
      'yearId': yearId, 'versionId': versionId,
      'version': versionId == null ? <String, Object?>{} : versions.firstWhere((v) => v['id'] == versionId, orElse: () => <String, Object?>{}),
      'versions': versions, 'entries': await db.entriesDetailed(versionId: versionId),
      'requirements': await db.requirementsDetailed(), 'slots': await db.rows('time_slots'),
      'teachers': await db.rows('teachers'), 'qualifications': await db.rows('teacher_subjects'), 'days': await db.rows('school_days'),
    };
  }

  Future<void> _exportPdf(Map<String, Object?> data, {bool preview = false}) async {
    setState(() => _busy = true);
    try {
      final settings = (data['settings'] as Map).cast<String, Object?>();
      final year = (data['year'] as Map).cast<String, Object?>();
      final version = (data['version'] as Map).cast<String, Object?>();
      final entries = (data['entries'] as List).cast<Map<String, Object?>>();
      final bytes = await PdfReportService().buildTimetablePdf(
        schoolName: settings['school_name']?.toString() ?? 'مدرستي',
        academicYear: year['name']?.toString() ?? 'غير محدد',
        versionName: version['name']?.toString() ?? 'الجدول الحالي',
        status: version['status']?.toString() ?? 'مسودة',
        entries: entries,
      );
      if (preview) {
        await PdfReportService().preview(bytes);
        if (mounted) showMessage(context, 'تم فتح معاينة التقرير.');
      } else {
        final path = await PdfReportService().savePdf(bytes, fileName: 'الجدول-الشامل-${DateTime.now().toIso8601String().split('T').first}.pdf');
        if (path != null && mounted) showMessage(context, 'تم حفظ ملف PDF في: $path');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'تعذر إنشاء PDF: $e', error: true);
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _exportCsv(Map<String, Object?> data) async {
    setState(() => _busy = true);
    try {
      final entries = (data['entries'] as List).cast<Map<String, Object?>>();
      String cell(Object? value) {
        final text = value?.toString() ?? '';
        return '"${text.replaceAll('"', '""')}"';
      }
      final rows = <List<Object?>>[
        ['اليوم', 'الفترة', 'البداية', 'النهاية', 'الصف', 'الشعبة', 'المادة', 'المعلم', 'القاعة'],
        ...entries.map((e) => [e['day_name'], e['slot_name'], e['start_time'], e['end_time'], e['grade_name'], e['section_name'], e['subject_name'], e['teacher_name'], e['room_name']]),
      ];
      final csv = '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير الجدول إلى CSV', fileName: 'الجدول-المدرسي.csv',
        type: FileType.custom, allowedExtensions: ['csv'], bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (path != null && mounted) showMessage(context, 'تم تصدير ${entries.length} حصة إلى: $path');
    } catch (e) { if (mounted) showMessage(context, 'تعذر تصدير CSV: $e', error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final path = await BackupService(DatabaseService.instance).exportBackup();
      if (path != null && mounted) showMessage(context, 'تم إنشاء النسخة الاحتياطية: $path');
    } catch (e) { if (mounted) showMessage(context, 'فشل إنشاء النسخة الاحتياطية: $e', error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _importBackup() async {
    final proceed = await confirmAction(context, 'استعادة نسخة احتياطية', 'ستُستبدل بيانات المدرسة الحالية بمحتويات النسخة المختارة. ينشئ التطبيق نسخة طوارئ محلية قبل الاستعادة. هل تريد المتابعة؟');
    if (!proceed) return;
    setState(() => _busy = true);
    try {
      final result = await BackupService(DatabaseService.instance).importBackup();
      if (result != null && mounted) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('تمت الاستعادة'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المدرسة: ${result['school_name']}'), Text('الشعب: ${result['sections']} • المعلمون: ${result['teachers']} • المواد: ${result['subjects']}'),
            Text('الحصص المحفوظة ضمن الأرشيف: ${result['entries']}'), const SizedBox(height: 8),
            Text('نسخة الطوارئ: ${result['emergency_backup']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
        ));
        setState(_reload); widget.onChanged();
      }
    } catch (e) { if (mounted) showMessage(context, 'فشلت الاستعادة ولم يُفترض تطبيق استعادة جزئية: $e', error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _approve(Map<String, Object?> data) async {
    final blockers = const ConflictDetectionService().scan(
      entries: (data['entries'] as List).cast<Map<String, Object?>>(),
      requirements: (data['requirements'] as List).cast<Map<String, Object?>>(),
      slots: (data['slots'] as List).cast<Map<String, Object?>>(),
      teachers: (data['teachers'] as List).cast<Map<String, Object?>>(),
      qualifications: (data['qualifications'] as List).cast<Map<String, Object?>>(),
      days: (data['days'] as List).cast<Map<String, Object?>>(),
    ).where((i) => i.severity == 'خطأ مانع').toList();
    if (blockers.isNotEmpty) {
      if (mounted) await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('لا يمكن اعتماد الجدول'),
        content: Text('تم اكتشاف ${blockers.length} خطأ مانع. عالجها من صفحة فحص التعارضات ثم أعد المحاولة.\n\n${blockers.take(5).map((e) => '• ${e.type}: ${e.message}').join('\n')}'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
      ));
      return;
    }
    final warnings = const ConflictDetectionService().scan(
      entries: (data['entries'] as List).cast<Map<String, Object?>>(),
      requirements: (data['requirements'] as List).cast<Map<String, Object?>>(),
      slots: (data['slots'] as List).cast<Map<String, Object?>>(),
      teachers: (data['teachers'] as List).cast<Map<String, Object?>>(),
      qualifications: (data['qualifications'] as List).cast<Map<String, Object?>>(),
      days: (data['days'] as List).cast<Map<String, Object?>>(),
    ).where((i) => i.severity == 'تحذير').length;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد اعتماد الجدول'),
      content: Text(warnings == 0 ? 'لم تُكتشف أخطاء مانعة أو تحذيرات. هل تريد اعتماد النسخة الحالية؟' : 'لا توجد أخطاء مانعة، لكن توجد $warnings تحذيراً. تأكد من مراجعتها. هل تريد الاعتماد وفق سياسة المدرسة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('مراجعة لاحقاً')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اعتماد'))],
    ));
    if (ok != true) return;
    final versionId = data['versionId'] as int?;
    if (versionId == null) return;
    final now = DateTime.now().toIso8601String();
    await DatabaseService.instance.edit('timetable_versions', versionId, {'status': 'معتمد', 'approved_at': now, 'updated_at': now});
    await DatabaseService.instance.log('اعتماد', 'timetable_versions', versionId, 'اعتماد الجدول بعد فحص التحقق');
    if (mounted) { showMessage(context, 'تم اعتماد الجدول وحفظ تاريخ الاعتماد.'); setState(_reload); widget.onChanged(); }
  }

  Future<void> _restoreVersion(Map<String, Object?> data, Map<String, Object?> version) async {
    if (version['is_active'] == 1) { showMessage(context, 'هذه هي النسخة النشطة بالفعل.'); return; }
    final ok = await confirmAction(context, 'استعادة نسخة جدول', 'سيتم إنشاء نسخة عمل جديدة من «${version['name']}». ستبقى النسخة الحالية والنسخة المختارة محفوظتين في الأرشيف.');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final db = await DatabaseService.instance.database;
      final oldEntries = await db.query('timetable_entries', where: 'version_id=?', whereArgs: [version['id']]);
      final stripped = oldEntries.map((e) {
        final row = Map<String, Object?>.from(e);
        row.remove('id'); row.remove('version_id'); row.remove('created_at');
        return row;
      }).toList();
      final id = await DatabaseService.instance.saveAsNewVersion(
        yearId: data['yearId'] as int, name: 'استعادة: ${version['name']}',
        entries: stripped, notes: 'نسخة مستعادة من النسخة رقم ${version['id']}.',
      );
      if (mounted) showMessage(context, 'تم إنشاء نسخة مستعادة جديدة برقم $id.');
      setState(_reload); widget.onChanged();
    } catch (e) { if (mounted) showMessage(context, 'تعذرت استعادة النسخة: $e', error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _compareWithActive(Map<String, Object?> data, Map<String, Object?> other) async {
    final db = await DatabaseService.instance.database;
    final versionId = data['versionId'] as int?;
    if (versionId == null) return;
    final currentRows = await db.query('timetable_entries', where: 'version_id=?', whereArgs: [versionId]);
    final otherRows = await db.query('timetable_entries', where: 'version_id=?', whereArgs: [other['id']]);
    String key(Map<String, Object?> e) => '${e['section_id']}:${e['day_id']}:${e['slot_id']}';
    final currentMap = {for (final e in currentRows) key(e): e};
    final otherMap = {for (final e in otherRows) key(e): e};
    var added = 0, removed = 0, changed = 0;
    final diffs = <String>[];
    for (final k in {...currentMap.keys, ...otherMap.keys}) {
      final a = currentMap[k], b = otherMap[k];
      if (a == null && b != null) { removed++; if (diffs.length < 10) diffs.add('أزيلت حصة من موقع $k'); }
      else if (a != null && b == null) { added++; if (diffs.length < 10) diffs.add('أضيفت حصة في موقع $k'); }
      else if (a != null && b != null && (a['subject_id'] != b['subject_id'] || a['teacher_id'] != b['teacher_id'] || a['room_id'] != b['room_id'])) { changed++; if (diffs.length < 10) diffs.add('تغيرت المادة أو المعلم في موقع $k'); }
    }
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('مقارنة مع «${other['name']}»'),
      content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مضاف في النسخة النشطة: $added'), Text('محذوف من النسخة النشطة: $removed'), Text('حصص تغيرت: $changed'), const SizedBox(height: 8),
        if (diffs.isNotEmpty) ...[const Text('أمثلة على التغييرات:', style: TextStyle(fontWeight: FontWeight.bold)), ...diffs.map((d) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $d', style: const TextStyle(fontSize: 12))))],
        const SizedBox(height: 6), const Text('مواقع المقارنة تظهر بمعرّفات داخلية (شعبة:يوم:فترة).', style: TextStyle(fontSize: 11, color: Colors.black54)),
      ])), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  String _prettyDate(Object? value) => value.toString().replaceFirst('T', ' ').split('.').first;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التقارير والنسخ الاحتياطي'), actions: [IconButton(onPressed: _busy ? null : () => setState(_reload), icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<Map<String, Object?>>(future: _future, builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final data = snapshot.data!;
      final version = (data['version'] as Map).cast<String, Object?>();
      final versions = (data['versions'] as List).cast<Map<String, Object?>>();
      final entries = (data['entries'] as List).cast<Map<String, Object?>>();
      final year = (data['year'] as Map).cast<String, Object?>();
      return Stack(children: [
        ListView(padding: const EdgeInsets.all(16), children: [
          pageHeading('التقارير والطباعة', 'تصدير الجدول المحفوظ حالياً؛ لا تظهر رسالة نجاح إذا فشل التوليد.'),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('تصدير الجدول الشامل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5), Text('${year['name'] ?? 'عام غير محدد'} • ${version['name'] ?? 'لا توجد نسخة'} • ${entries.length} حصة', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: _busy ? null : () => _exportPdf(data), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('حفظ الجدول الشامل PDF'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48))),
            const SizedBox(height: 8), OutlinedButton.icon(onPressed: _busy ? null : () => _exportPdf(data, preview: true), icon: const Icon(Icons.preview_outlined), label: const Text('معاينة PDF'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46))),
            const SizedBox(height: 8), OutlinedButton.icon(onPressed: _busy ? null : () => _exportCsv(data), icon: const Icon(Icons.table_view_outlined), label: const Text('تصدير البيانات إلى CSV'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46))),
            const SizedBox(height: 8), const Text('يتطلب PDF خطاً عربياً متاحاً على الجهاز. إذا تعذر العثور على الخط سيعرض التطبيق رسالة خطأ واضحة.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]))),
          const SizedBox(height: 18),
          const Text('النسخ الاحتياطي والاستعادة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
            ListTile(leading: const Icon(Icons.backup_outlined, color: Color(0xFF2878C8), size: 30), title: const Text('إنشاء نسخة احتياطية'), subtitle: const Text('JSON يشمل قاعدة البيانات والنسخ المؤرشفة والإعدادات.'), trailing: const Icon(Icons.chevron_left), onTap: _busy ? null : _exportBackup),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.restore_outlined, color: Color(0xFFB87419), size: 30), title: const Text('استعادة نسخة احتياطية'), subtitle: const Text('يتحقق من إصدار المخطط وينشئ نسخة طوارئ قبل الاستعادة.'), trailing: const Icon(Icons.chevron_left), onTap: _busy ? null : _importBackup),
          ]))),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('دورة اعتماد الجدول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6), Text('الحالة الحالية: ${version['status'] ?? 'مسودة'}'),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _busy || data['versionId'] == null ? null : () => _approve(data), icon: const Icon(Icons.verified_outlined), label: const Text('فحص ثم اعتماد الجدول'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16845B), minimumSize: const Size.fromHeight(46))),
            const SizedBox(height: 5), const Text('لن يسمح التطبيق بالاعتماد عند اكتشاف أخطاء مانعة. التحذيرات تُعرض قبل الاعتماد.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]))),
          const SizedBox(height: 18),
          const Text('أرشيف نسخ الجداول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
          if (versions.isEmpty) emptyState(icon: Icons.history, title: 'لا توجد نسخ', message: 'أنشئ جدولاً أو نتيجة جدولة تلقائية لتبدأ إدارة النسخ.'),
          ...versions.map((v) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
            leading: Icon(v['is_active'] == 1 ? Icons.radio_button_checked : Icons.history, color: v['is_active'] == 1 ? const Color(0xFF16845B) : const Color(0xFF8CA3BA)),
            title: Text('${v['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${v['status']} • ${_prettyDate(v['created_at'])}'),
            trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'compare') _compareWithActive(data, v); if (value == 'restore') _restoreVersion(data, v); }, itemBuilder: (_) => [const PopupMenuItem(value: 'compare', child: Text('مقارنة مع النشطة')), if (v['is_active'] != 1) const PopupMenuItem(value: 'restore', child: Text('استعادة كنسخة جديدة'))]),
          )))),
          const SizedBox(height: 22),
          const Text('البيانات محفوظة محلياً على هذا الجهاز، وينصح بإنشاء نسخة احتياطية قبل استعادة أي ملف أو تجربة إعدادات جديدة.', style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
        if (_busy) Container(color: Colors.black.withValues(alpha: .25), child: const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 14), Text('جارٍ تنفيذ العملية...')]))))),
      ]);
    }),
  );
}
