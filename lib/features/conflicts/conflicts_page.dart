import 'package:flutter/material.dart';

import '../../core/ui_helpers.dart';
import '../../data/database_service.dart';
import '../../services/conflict_detection_service.dart';

class ConflictsPage extends StatefulWidget {
  const ConflictsPage({super.key});
  @override
  State<ConflictsPage> createState() => _ConflictsPageState();
}

class _ConflictsPageState extends State<ConflictsPage> {
  Future<Map<String, Object?>>? _future;
  String _filter = 'الكل';
  bool _scanned = false;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _future = _load();

  Future<Map<String, Object?>> _load() async {
    final db = DatabaseService.instance;
    final versionId = await db.activeVersionId(await db.activeYearId());
    final data = <String, Object?>{
      'versionId': versionId,
      'version': versionId == null ? <String, Object?>{} : (await db.rows('timetable_versions')).firstWhere((v) => v['id'] == versionId, orElse: () => <String, Object?>{}),
      'entries': await db.entriesDetailed(versionId: versionId),
      'requirements': await db.requirementsDetailed(),
      'slots': await db.rows('time_slots'),
      'teachers': await db.rows('teachers'),
      'qualifications': await db.rows('teacher_subjects'),
      'days': await db.rows('school_days'),
    };
    return data;
  }

  List<ConflictIssue> _scan(Map<String, Object?> data) => const ConflictDetectionService().scan(
    entries: (data['entries'] as List).cast<Map<String, Object?>>(),
    requirements: (data['requirements'] as List).cast<Map<String, Object?>>(),
    slots: (data['slots'] as List).cast<Map<String, Object?>>(),
    teachers: (data['teachers'] as List).cast<Map<String, Object?>>(),
    qualifications: (data['qualifications'] as List).cast<Map<String, Object?>>(),
    days: (data['days'] as List).cast<Map<String, Object?>>(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('فحص التعارضات')),
    body: FutureBuilder<Map<String, Object?>>(future: _future, builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return emptyState(icon: Icons.error_outline, title: 'تعذر فحص الجدول', message: '${snapshot.error}');
      final data = snapshot.data!;
      final entries = (data['entries'] as List).cast<Map<String, Object?>>();
      final issues = _scan(data);
      final blockers = issues.where((i) => i.severity == 'خطأ مانع').length;
      final warnings = issues.where((i) => i.severity == 'تحذير').length;
      final notes = issues.where((i) => i.severity == 'ملاحظة').length;
      final filtered = _filter == 'الكل' ? issues : issues.where((i) => i.severity == _filter).toList();
      final version = (data['version'] as Map).cast<String, Object?>();
      return ListView(padding: const EdgeInsets.all(16), children: [
        pageHeading('فحص صحة الجدول', 'تُعاد قراءة بيانات النسخة النشطة من SQLite عند فتح هذه الصفحة.', trailing: IconButton(onPressed: () => setState(() { _reload(); _scanned = true; }), icon: const Icon(Icons.refresh, color: Color(0xFF2878C8)))),
        Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
          const Icon(Icons.fact_check_outlined, size: 30, color: Color(0xFF2878C8)), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${version['name'] ?? 'لا توجد نسخة'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text('الحالة: ${version['status'] ?? '—'} • حصص محفوظة: ${entries.length}', style: const TextStyle(color: Colors.black54, fontSize: 12))])),
          FilledButton.icon(onPressed: () => setState(() { _reload(); _scanned = true; }), icon: const Icon(Icons.manage_search), label: const Text('فحص الآن')),
        ]))),
        const SizedBox(height: 12),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 1, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: MediaQuery.sizeOf(context).width > 600 ? 1.9 : 3.2, children: [
          _IssueSummary(title: 'أخطاء مانعة', value: blockers, color: Colors.red.shade700, icon: Icons.error_outline),
          _IssueSummary(title: 'تحذيرات', value: warnings, color: Colors.deepOrange.shade700, icon: Icons.warning_amber_outlined),
          _IssueSummary(title: 'ملاحظات', value: notes, color: const Color(0xFF2878C8), icon: Icons.info_outline),
        ]),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('النتيجة النهائية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 8),
          Text(blockers > 0 ? 'لا يمكن اعتماد الجدول حالياً؛ يجب معالجة الأخطاء المانعة أولاً.' : warnings > 0 ? 'لا توجد أخطاء مانعة مكتشفة، لكن توجد تحذيرات ينبغي مراجعتها قبل الاعتماد.' : 'لم تُكتشف أخطاء مانعة أو تحذيرات ضمن الفحوص المفعلة.'),
          if (_scanned) const Padding(padding: EdgeInsets.only(top: 6), child: Text('أُعيد تشغيل الفحص بناءً على البيانات الحالية.', style: TextStyle(fontSize: 12, color: Colors.black54))),
        ]))),
        const SizedBox(height: 12),
        Row(children: [const Expanded(child: Text('تفاصيل النتائج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), SizedBox(width: 160, child: DropdownButtonFormField<String>(value: _filter, isExpanded: true, decoration: const InputDecoration(labelText: 'تصفية'), items: const [DropdownMenuItem(value: 'الكل', child: Text('كل النتائج')), DropdownMenuItem(value: 'خطأ مانع', child: Text('أخطاء مانعة')), DropdownMenuItem(value: 'تحذير', child: Text('تحذيرات')), DropdownMenuItem(value: 'ملاحظة', child: Text('ملاحظات'))], onChanged: (v) => setState(() => _filter = v ?? 'الكل')))]),
        const SizedBox(height: 8),
        if (filtered.isEmpty) emptyState(icon: Icons.check_circle_outline, title: 'لا توجد نتائج ضمن هذا التصنيف', message: 'قد يكون الجدول خالياً أو اجتاز الفحوص الحالية. تحقق من تسجيل متطلبات المواد إذا كان ذلك مطلوباً.'),
        ...filtered.map((issue) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ExpansionTile(
          leading: Icon(_iconFor(issue.severity), color: _colorFor(issue.severity)),
          title: Text(issue.type, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(issue.message, maxLines: 3, overflow: TextOverflow.ellipsis),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            Align(alignment: Alignment.centerRight, child: Chip(label: Text(issue.severity), backgroundColor: _colorFor(issue.severity).withValues(alpha: .12))),
            if (issue.suggestion != null) Align(alignment: Alignment.centerRight, child: Text('الاقتراح: ${issue.suggestion}')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (issue.sectionId != null) _InfoPill(label: 'معرّف الشعبة', value: '${issue.sectionId}'),
              if (issue.teacherId != null) _InfoPill(label: 'معرّف المعلم', value: '${issue.teacherId}'),
              if (issue.dayId != null) _InfoPill(label: 'اليوم', value: '${issue.dayId}'),
              if (issue.slotId != null) _InfoPill(label: 'الفترة', value: '${issue.slotId}'),
            ]),
          ],
        )))),
      ]);
    }),
  );

  IconData _iconFor(String severity) => switch (severity) { 'خطأ مانع' => Icons.error_outline, 'تحذير' => Icons.warning_amber_outlined, _ => Icons.info_outline };
  Color _colorFor(String severity) => switch (severity) { 'خطأ مانع' => Colors.red.shade700, 'تحذير' => Colors.deepOrange.shade700, _ => const Color(0xFF2878C8) };
}

class _IssueSummary extends StatelessWidget {
  const _IssueSummary({required this.title, required this.value, required this.color, required this.icon});
  final String title; final int value; final Color color; final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon, color: color, size: 28), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), Text('$value', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: color))])));
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});
  final String label; final String value;
  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'), visualDensity: VisualDensity.compact);
}
