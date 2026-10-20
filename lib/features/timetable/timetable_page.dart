import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ui_helpers.dart';
import '../../data/database_service.dart';
import '../../services/auto_scheduler_service.dart';
import '../../services/conflict_detection_service.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({required this.onChanged, super.key});
  final VoidCallback onChanged;
  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  Future<Map<String, Object?>>? _future;
  int? _sectionFilter;
  int? _dayFilter;
  bool _isGenerating = false;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _future = _loadData();

  Future<Map<String, Object?>> _loadData() async {
    final db = DatabaseService.instance;
    final yearId = await db.activeYearId();
    final versionId = await db.activeVersionId(yearId);
    return {
      'year': await db.activeYear() ?? <String, Object?>{},
      'versionId': versionId,
      'version': versionId == null ? <String, Object?>{} : (await db.rows('timetable_versions')).firstWhere((v) => v['id'] == versionId, orElse: () => <String, Object?>{}),
      'sections': await db.sectionsDetailed(),
      'subjects': await db.rows('subjects', orderBy: 'name'),
      'teachers': await db.rows('teachers', orderBy: 'name'),
      'qualifications': await db.rows('teacher_subjects'),
      'days': await db.rows('school_days', orderBy: 'position'),
      'slots': await db.rows('time_slots', orderBy: 'position'),
      'entries': await db.entriesDetailed(versionId: versionId),
      'requirements': await db.requirementsDetailed(),
      'availability': await db.rows('teacher_availability'),
      'yearId': yearId,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('محرر الجدول الأسبوعي'), actions: [
      IconButton(tooltip: 'تحديث', onPressed: () => setState(_reload), icon: const Icon(Icons.refresh)),
      IconButton(tooltip: 'الجدولة التلقائية', onPressed: _isGenerating ? null : _generateAutomatically, icon: const Icon(Icons.auto_awesome)),
    ]),
    body: FutureBuilder<Map<String, Object?>>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return emptyState(icon: Icons.error_outline, title: 'تعذر تحميل الجدول', message: '${snapshot.error}');
      final data = snapshot.data!;
      final sections = (data['sections'] as List).cast<Map<String, Object?>>();
      final subjects = (data['subjects'] as List).cast<Map<String, Object?>>();
      final teachers = (data['teachers'] as List).cast<Map<String, Object?>>();
      final qualifications = (data['qualifications'] as List).cast<Map<String, Object?>>();
      final days = (data['days'] as List).cast<Map<String, Object?>>().where((d) => d['is_active'] == 1).toList();
      final slots = (data['slots'] as List).cast<Map<String, Object?>>();
      final entries = (data['entries'] as List).cast<Map<String, Object?>>();
      final requirements = (data['requirements'] as List).cast<Map<String, Object?>>();
      final allSections = sections;
      final visibleSections = _sectionFilter == null ? allSections : allSections.where((s) => s['id'] == _sectionFilter).toList();
      final visibleDays = _dayFilter == null ? days : days.where((d) => d['id'] == _dayFilter).toList();
      final version = (data['version'] as Map).cast<String, Object?>();
      final year = (data['year'] as Map).cast<String, Object?>();

      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10), child: Column(children: [
          Row(children: [
            Expanded(child: DropdownButtonFormField<int?>(
              value: _sectionFilter, isExpanded: true,
              decoration: const InputDecoration(labelText: 'عرض الشعبة', prefixIcon: Icon(Icons.groups_outlined)),
              items: [const DropdownMenuItem<int?>(value: null, child: Text('جميع الشعب')),
                ...sections.map((s) => DropdownMenuItem<int?>(value: s['id'] as int, child: Text('${s['grade_name']} - ${s['section_name']}', overflow: TextOverflow.ellipsis)))],
              onChanged: (value) async {
                setState(() => _sectionFilter = value);
                final prefs = await SharedPreferences.getInstance();
                if (value == null) { await prefs.remove('last_timetable_section_filter'); } else { await prefs.setInt('last_timetable_section_filter', value); }
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<int?>(
              value: _dayFilter, isExpanded: true,
              decoration: const InputDecoration(labelText: 'اليوم', prefixIcon: Icon(Icons.today_outlined)),
              items: [const DropdownMenuItem<int?>(value: null, child: Text('كل الأيام')),
                ...days.map((d) => DropdownMenuItem<int?>(value: d['id'] as int, child: Text('${d['name']}')))],
              onChanged: (value) => setState(() => _dayFilter = value),
            )),
          ]),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: Row(children: [
            const Icon(Icons.history_toggle_off, color: Color(0xFF2878C8)), const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${year['name'] ?? 'عام غير محدد'} • ${version['name'] ?? 'لا توجد نسخة'}', style: const TextStyle(fontWeight: FontWeight.w800)), Text('الحالة: ${version['status'] ?? 'مسودة'} • ${entries.length} حصة محفوظة', style: const TextStyle(color: Colors.black54, fontSize: 12))])),
            IconButton(tooltip: 'إنشاء جدول تلقائي', onPressed: _isGenerating ? null : _generateAutomatically, icon: const Icon(Icons.auto_awesome, color: Color(0xFF2878C8))),
          ]))),
        ])),
        Expanded(child: sections.isEmpty ? emptyState(icon: Icons.groups_outlined, title: 'لا توجد شعب', message: 'أضف الصفوف والشعب من تبويب إدارة البيانات أولاً.')
          : subjects.isEmpty || teachers.isEmpty ? emptyState(icon: Icons.info_outline, title: 'أكمل بيانات المدرسة', message: 'أضف مادة ومعلماً واحداً على الأقل، ثم حدّد المواد المؤهلة للمعلمين من إدارة البيانات.')
          : slots.where((s) => s['kind'] == 'lesson').isEmpty || days.isEmpty ? emptyState(icon: Icons.access_time, title: 'لا توجد أوقات متاحة', message: 'فعّل أيام الدوام وأضف فترات من نوع حصة دراسية في إعدادات المدرسة.')
          : visibleSections.isEmpty ? emptyState(icon: Icons.search_off, title: 'لا توجد نتائج', message: 'غيّر تصفية الشعبة لعرض الجدول.')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
              if (requirements.isEmpty) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFFFFF3D8), borderRadius: BorderRadius.circular(14)), child: const Text('لم تُسجّل الحصص الأسبوعية المطلوبة بعد؛ يمكنك إدخال حصص يدوياً، لكن الجدولة التلقائية تحتاج متطلبات المواد لكل شعبة.', style: TextStyle(color: Color(0xFF865300)))),
              ...visibleSections.map((section) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _buildSectionTable(
                section: section, days: visibleDays, slots: slots, entries: entries, requirements: requirements,
                subjects: subjects, teachers: teachers, qualifications: qualifications, allSlots: slots,
                allDays: days,
              ))),
            ])),
      ]);
    }),
  );

  Widget _buildSectionTable({
    required Map<String, Object?> section,
    required List<Map<String, Object?>> days,
    required List<Map<String, Object?>> slots,
    required List<Map<String, Object?>> entries,
    required List<Map<String, Object?>> requirements,
    required List<Map<String, Object?>> subjects,
    required List<Map<String, Object?>> teachers,
    required List<Map<String, Object?>> qualifications,
    required List<Map<String, Object?>> allSlots,
    required List<Map<String, Object?>> allDays,
  }) {
    final sectionId = section['id'] as int;
    final sectionEntries = entries.where((e) => e['section_id'] == sectionId).toList();
    final activeSlots = slots;
    return Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 4), child: Row(children: [
        Container(width: 4, height: 34, decoration: BoxDecoration(color: const Color(0xFF2878C8), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${section['grade_name']} - ${section['section_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text('${sectionEntries.length} حصة موزعة', style: const TextStyle(color: Colors.black54, fontSize: 12))])),
        IconButton(tooltip: 'إضافة حصة للشعبة', onPressed: days.isEmpty || activeSlots.where((s) => s['kind'] == 'lesson').isEmpty ? null : () => _chooseCell(section, days, activeSlots, sectionEntries, entries, requirements, subjects, teachers, qualifications, allSlots, allDays), icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2878C8))),
      ])),
      const Divider(height: 1),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 8, columnSpacing: 8, dataRowMinHeight: 58, dataRowMaxHeight: 74,
          columns: [const DataColumn(label: SizedBox(width: 100, child: Text('الفترة / الوقت'))), ...days.map((d) => DataColumn(label: SizedBox(width: 128, child: Text('${d['name']}', textAlign: TextAlign.center))))],
          rows: activeSlots.map((slot) {
            final isLesson = slot['kind'] == 'lesson' && slot['is_available'] == 1;
            return DataRow(cells: [
              DataCell(SizedBox(width: 100, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${slot['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                Text('${slot['start_time']}–${slot['end_time']}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                if (!isLesson) Text(_periodLabel('${slot['kind']}'), style: const TextStyle(fontSize: 10, color: Colors.deepOrange)),
              ]))),
              ...days.map((day) {
                final matches = sectionEntries.where((e) => e['day_id'] == day['id'] && e['slot_id'] == slot['id']).toList();
                final entry = matches.isEmpty ? null : matches.first;
                final filled = entry != null;
                return DataCell(SizedBox(width: 128, child: Material(
                  color: !isLesson ? const Color(0xFFF0F2F4) : filled ? const Color(0xFFE9F2FC) : const Color(0xFFFAFBFD),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (!isLesson) { showMessage(context, 'هذه الفترة ليست متاحة للتدريس.'); return; }
                      _editCell(section, day, slot, entry, allSlots, entries, requirements, subjects, teachers, qualifications, allDays);
                    },
                    onLongPress: filled ? () => _editCell(section, day, slot, entry, allSlots, entries, requirements, subjects, teachers, qualifications, allDays) : null,
                    child: Padding(padding: const EdgeInsets.all(7), child: filled ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${entry['subject_name'] ?? 'مادة'}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF183B66))),
                      const SizedBox(height: 3), Text('${entry['teacher_name'] ?? 'غير مسند'}', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ]) : Center(child: Icon(isLesson ? Icons.add : Icons.block, size: 16, color: isLesson ? const Color(0xFF9CB5CE) : Colors.black26))),
                  ),
                )));
              }),
            ]);
          }).toList(),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: Row(children: [
        const Icon(Icons.touch_app_outlined, size: 15, color: Colors.black45), const SizedBox(width: 5),
        const Expanded(child: Text('اضغط الخلية لإضافة أو تعديل الحصة، أو اضغط مطولاً لفتح تفاصيلها.', style: TextStyle(fontSize: 11, color: Colors.black54))),
        TextButton(onPressed: () async { if (await confirmAction(context, 'تفريغ جدول الشعبة', 'سيتم حذف جميع حصص هذه الشعبة من نسخة العمل النشطة. هل تريد المتابعة؟')) { final db = await DatabaseService.instance.database; final yearId = await DatabaseService.instance.activeYearId(); final versionId = yearId == null ? null : await DatabaseService.instance.ensureEditableActiveVersion(yearId); if (versionId != null) { await db.delete('timetable_entries', where: 'version_id=? AND section_id=?', whereArgs: [versionId, sectionId]); await db.update('timetable_versions', {'status': 'قيد التعديل', 'updated_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [versionId]); setState(_reload); widget.onChanged(); } } }, child: const Text('تفريغ الشعبة')),
      ])),
    ]));
  }

  String _periodLabel(String kind) => switch (kind) { 'break' => 'استراحة', 'activity' => 'نشاط', _ => 'غير متاحة' };

  Future<void> _chooseCell(
    Map<String, Object?> section, List<Map<String, Object?>> days, List<Map<String, Object?>> slots,
    List<Map<String, Object?>> sectionEntries, List<Map<String, Object?>> allEntries, List<Map<String, Object?>> requirements,
    List<Map<String, Object?>> subjects, List<Map<String, Object?>> teachers,
    List<Map<String, Object?>> qualifications, List<Map<String, Object?>> allSlots,
    List<Map<String, Object?>> allDays,
  ) async {
    final choices = <Map<String, Object?>>[];
    for (final day in days) {
      for (final slot in slots.where((s) => s['kind'] == 'lesson' && s['is_available'] == 1)) {
        if (!sectionEntries.any((e) => e['day_id'] == day['id'] && e['slot_id'] == slot['id'])) choices.add({'day': day, 'slot': slot});
      }
    }
    if (choices.isEmpty) { showMessage(context, 'لا توجد خلايا فارغة في جدول هذه الشعبة.'); return; }
    final selected = await showDialog<Map<String, Object?>>(context: context, builder: (ctx) => SimpleDialog(title: const Text('اختر خلية لإضافة حصة'), children: choices.take(80).map((c) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text('${(c['day'] as Map)['name']} • ${(c['slot'] as Map)['name']} (${(c['slot'] as Map)['start_time']})'))).toList()));
    if (selected != null) await _editCell(section, selected['day'] as Map<String, Object?>, selected['slot'] as Map<String, Object?>, null, allSlots, allEntries, requirements, subjects, teachers, qualifications, allDays);
  }

  Future<void> _editCell(
    Map<String, Object?> section, Map<String, Object?> day, Map<String, Object?> slot,
    Map<String, Object?>? entry, List<Map<String, Object?>> slots, List<Map<String, Object?>> allEntries,
    List<Map<String, Object?>> allRequirements, List<Map<String, Object?>> allSubjects,
    List<Map<String, Object?>> allTeachers, List<Map<String, Object?>> qualifications,
    List<Map<String, Object?>> allDays,
  ) async {
    final sectionId = section['id'] as int;
    final sectionRequirements = allRequirements.where((r) => r['section_id'] == sectionId).toList();
    final subjectIds = sectionRequirements.map((r) => r['subject_id']).toSet();
    final availableSubjects = subjectIds.isEmpty ? allSubjects : allSubjects.where((s) => subjectIds.contains(s['id'])).toList();
    if (availableSubjects.isEmpty) { showMessage(context, 'أضف مادة أولاً.'); return; }
    int? selectedSubject = entry?['subject_id'] as int? ?? availableSubjects.first['id'] as int;
    int? selectedTeacher = entry?['teacher_id'] as int?;
    final result = await showDialog<Map<String, Object?>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
      final qualifiedIds = qualifications.where((q) => q['subject_id'] == selectedSubject).map((q) => q['teacher_id']).toSet();
      final teacherOptions = allTeachers.where((t) => qualifiedIds.contains(t['id'])).toList();
      final selectedTeacherAvailable = selectedTeacher == null || teacherOptions.any((t) => t['id'] == selectedTeacher);
      return AlertDialog(
        title: Text(entry == null ? 'إضافة حصة' : 'تعديل الحصة'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(alignment: Alignment.centerRight, child: Text('${section['grade_name']} - ${section['section_name']}\n${day['name']} • ${slot['name']} (${slot['start_time']}–${slot['end_time']})', style: const TextStyle(color: Colors.black54))),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(value: selectedSubject, isExpanded: true, decoration: const InputDecoration(labelText: 'المادة'), items: availableSubjects.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']}'))).toList(), onChanged: (v) => update(() { selectedSubject = v; selectedTeacher = null; })),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(value: selectedTeacherAvailable ? selectedTeacher : null, isExpanded: true, decoration: const InputDecoration(labelText: 'المعلم المؤهل'), items: [const DropdownMenuItem<int?>(value: null, child: Text('غير مسند حالياً')), ...teacherOptions.map((t) => DropdownMenuItem<int?>(value: t['id'] as int, child: Text('${t['name']}')))], onChanged: (v) => update(() => selectedTeacher = v)),
          if (teacherOptions.isEmpty) const Padding(padding: EdgeInsets.only(top: 9), child: Text('لا يوجد معلم مؤهل لهذه المادة. سجّل تأهيل المعلمين أولاً؛ يمكن حفظ الحصة دون معلم مع ظهور تحذير.', style: TextStyle(color: Colors.deepOrange, fontSize: 12))),
        ])),
        actions: [
          if (entry != null) TextButton(onPressed: () => Navigator.pop(ctx, {'delete': true}), child: const Text('حذف الحصة', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, {'subject_id': selectedSubject, 'teacher_id': selectedTeacher}), child: const Text('حفظ')),
        ],
      );
    }));
    if (result == null) return;
    if (result['delete'] == true) {
      if (!await confirmAction(context, 'حذف الحصة', 'هل تريد حذف الحصة المحددة؟')) return;
      try {
        final db = await DatabaseService.instance.database;
        final yearId = await DatabaseService.instance.activeYearId();
        final versionId = yearId == null ? null : await DatabaseService.instance.ensureEditableActiveVersion(yearId);
        if (versionId == null) throw StateError('لا توجد نسخة نشطة قابلة للتعديل.');
        final cloned = await db.query('timetable_entries', where: 'version_id=? AND section_id=? AND day_id=? AND slot_id=?', whereArgs: [versionId, sectionId, day['id'], slot['id']], limit: 1);
        if (cloned.isEmpty) throw StateError('لم يتم العثور على الحصة في نسخة العمل.');
        await db.delete('timetable_entries', where: 'id=?', whereArgs: [cloned.first['id']]);
        await db.update('timetable_versions', {'status': 'قيد التعديل', 'updated_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [versionId]);
        if (mounted) { showMessage(context, 'تم حذف الحصة.'); setState(_reload); widget.onChanged(); }
      } catch (e) { if (mounted) showMessage(context, 'تعذر حذف الحصة: $e', error: true); }
      return;
    }
    final newEntry = <String, Object?>{
      'id': entry?['id'] ?? -1,
      'section_id': sectionId, 'subject_id': result['subject_id'], 'teacher_id': result['teacher_id'],
      'room_id': entry?['room_id'], 'day_id': day['id'], 'slot_id': slot['id'],
      'version_id': entry?['version_id'] ?? (await DatabaseService.instance.activeVersionId(await DatabaseService.instance.activeYearId())),
      'subject_name': availableSubjects.firstWhere((s) => s['id'] == result['subject_id'])['name'],
      'section_name': section['section_name'], 'teacher_name': result['teacher_id'] == null ? null : allTeachers.firstWhere((t) => t['id'] == result['teacher_id'])['name'],
    };
    if (newEntry['version_id'] == null) { showMessage(context, 'لا يوجد عام دراسي نشط.', error: true); return; }
    final entriesForScan = allEntries.where((e) => e['id'] != entry?['id']).toList()..add(newEntry);
    final slotsForScan = slots;
    final issues = const ConflictDetectionService().scan(
      entries: entriesForScan, requirements: allRequirements, slots: slotsForScan,
      teachers: allTeachers, qualifications: qualifications, days: allDays,
      enforceQualifications: true,
    );
    final blockers = issues.where((i) => i.severity == 'خطأ مانع' && i.dayId == day['id'] && i.slotId == slot['id'] &&
      (i.sectionId == sectionId || (result['teacher_id'] != null && i.teacherId == result['teacher_id']) || i.type == 'تأهيل المعلم' || i.type == 'فترة غير متاحة')).toList();
    if (blockers.isNotEmpty) {
      if (mounted) await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('لا يمكن حفظ الحصة بسبب تعارض'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: blockers.map((i) => ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: Text(i.type), subtitle: Text(i.message))).toList())),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع للتعديل'))],
      ));
      return;
    }
    try {
      final yearId = await DatabaseService.instance.activeYearId();
      if (yearId == null) throw StateError('لا يوجد عام دراسي نشط.');
      final writableVersionId = await DatabaseService.instance.ensureEditableActiveVersion(yearId);
      if (writableVersionId == null) throw StateError('لا توجد نسخة نشطة قابلة للتعديل.');
      int? targetEntryId;
      if (entry != null) {
        final db = await DatabaseService.instance.database;
        final cloned = await db.query('timetable_entries', where: 'version_id=? AND section_id=? AND day_id=? AND slot_id=?', whereArgs: [writableVersionId, sectionId, day['id'], slot['id']], limit: 1);
        if (cloned.isNotEmpty) targetEntryId = cloned.first['id'] as int;
      }
      final values = Map<String, Object?>.from(newEntry)
        ..['version_id'] = writableVersionId
        ..remove('id')..remove('subject_name')..remove('section_name')..remove('teacher_name');
      await DatabaseService.instance.saveEntry(values, entryId: targetEntryId);
      if (mounted) {
        showMessage(context, result['teacher_id'] == null ? 'حُفظت الحصة دون معلم؛ راجع التحذيرات قبل الاعتماد.' : 'تم حفظ الحصة دون تعارضات مانعة.');
        setState(_reload); widget.onChanged();
      }
    } catch (e) { if (mounted) showMessage(context, 'تعذر حفظ الحصة. قد تكون الخلية مشغولة: $e', error: true); }
  }

  Future<void> _generateAutomatically() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final data = await _loadData();
      final yearId = data['yearId'] as int?;
      if (yearId == null) throw StateError('أنشئ عاماً دراسياً نشطاً أولاً.');
      final sections = (data['sections'] as List).cast<Map<String, Object?>>();
      final filteredSections = _sectionFilter == null ? sections : sections.where((s) => s['id'] == _sectionFilter).toList();
      final sectionIds = filteredSections.map((s) => s['id']).toSet();
      final requirements = (data['requirements'] as List).cast<Map<String, Object?>>().where((r) => sectionIds.contains(r['section_id'])).toList();
      if (filteredSections.isEmpty || requirements.isEmpty) throw StateError('أضف الشعب وحدد الحصص الأسبوعية المطلوبة لكل مادة قبل بدء الجدولة.');
      final result = const AutoSchedulerService(nodeLimit: 30000).generate(
        sections: filteredSections, requirements: requirements,
        teachers: (data['teachers'] as List).cast<Map<String, Object?>>(),
        qualifications: (data['qualifications'] as List).cast<Map<String, Object?>>(),
        days: (data['days'] as List).cast<Map<String, Object?>>(),
        slots: (data['slots'] as List).cast<Map<String, Object?>>(),
        teacherAvailability: (data['availability'] as List).cast<Map<String, Object?>>(),
      );
      if (!mounted) return;
      final approve = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
        title: Text(result.complete ? 'نتيجة الجدولة مكتملة' : 'نتيجة جزئية — تحتاج مراجعة'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: _ResultMetric(label: 'المطلوب', value: '${result.requestedCount}')), Expanded(child: _ResultMetric(label: 'الموزع', value: '${result.placements.length}')), Expanded(child: _ResultMetric(label: 'المتبقي', value: '${result.requestedCount - result.placements.length}'))]),
          const SizedBox(height: 10), Text('عُقد البحث المفحوصة: ${result.exploredNodes}${result.searchLimitReached ? ' (وصل البحث إلى الحد المحدد)' : ''}'),
          const SizedBox(height: 10), Text(result.complete ? 'يمكن حفظ النتيجة كنسخة جديدة؛ ستبقى النسخة السابقة محفوظة في الأرشيف.' : 'لم تُوزع جميع الحصص. لم يتغير الجدول الحالي، ولن تُستبدل النسخة الحالية بنتيجة ناقصة.'),
          if (result.unscheduled.isNotEmpty) ...[
            const SizedBox(height: 12), const Text('الحصص غير الموزعة والأسباب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            ...result.unscheduled.take(12).map((reason) => Padding(padding: const EdgeInsets.only(top: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.warning_amber, size: 18, color: Colors.deepOrange), const SizedBox(width: 6), Expanded(child: Text(reason, style: const TextStyle(fontSize: 12)))]))),
            if (result.unscheduled.length > 12) Text('... و${result.unscheduled.length - 12} حالات أخرى'),
          ],
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إغلاق')), if (result.complete) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ كنسخة جديدة'))],
      ));
      if (approve == true) {
        final activeYear = (data['year'] as Map)['name']?.toString() ?? 'العام';
        final preserved = _sectionFilter == null ? <Map<String, Object?>>[] :
          (data['entries'] as List).cast<Map<String, Object?>>().where((e) => e['section_id'] != _sectionFilter).map((e) => <String, Object?>{
            'section_id': e['section_id'], 'subject_id': e['subject_id'], 'teacher_id': e['teacher_id'],
            'room_id': e['room_id'], 'day_id': e['day_id'], 'slot_id': e['slot_id'],
          }).toList();
        final newId = await DatabaseService.instance.saveAsNewVersion(
          yearId: yearId, name: 'جدول تلقائي ${DateTime.now().toString().substring(0, 16)}',
          entries: [...preserved, ...result.placements],
          notes: 'مولد آلياً لـ $activeYear؛ عقد البحث ${result.exploredNodes}.',
        );
        if (mounted) showMessage(context, 'تم حفظ النتيجة في النسخة رقم $newId، مع الاحتفاظ بالنسخة السابقة.');
        setState(_reload); widget.onChanged();
      }
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF183B66))), Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12))]);
}
