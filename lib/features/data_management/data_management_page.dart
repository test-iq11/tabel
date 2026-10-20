import 'package:flutter/material.dart';

import '../../core/ui_helpers.dart';
import '../../data/database_service.dart';

class DataManagementPage extends StatelessWidget {
  const DataManagementPage({required this.onChanged, super.key});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      appBar: AppBar(title: const Text('إدارة بيانات المدرسة'), bottom: const TabBar(
        isScrollable: true,
        tabs: [
          Tab(icon: Icon(Icons.groups_outlined), text: 'الصفوف والشعب'),
          Tab(icon: Icon(Icons.menu_book_outlined), text: 'المواد'),
          Tab(icon: Icon(Icons.co_present_outlined), text: 'المعلمون'),
          Tab(icon: Icon(Icons.rule_folder_outlined), text: 'الحصص المطلوبة'),
          Tab(icon: Icon(Icons.settings_outlined), text: 'المدرسة والأوقات'),
        ],
      )),
      body: TabBarView(children: [
        _GradesSectionsTab(onChanged: onChanged),
        _SubjectsTab(onChanged: onChanged),
        _TeachersTab(onChanged: onChanged),
        _RequirementsTab(onChanged: onChanged),
        _SettingsTab(onChanged: onChanged),
      ]),
    ),
  );
}

class _GradesSectionsTab extends StatefulWidget {
  const _GradesSectionsTab({required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<_GradesSectionsTab> createState() => _GradesSectionsTabState();
}

class _GradesSectionsTabState extends State<_GradesSectionsTab> {
  Future<List<dynamic>> _load() async => Future.wait([
    DatabaseService.instance.gradesDetailed(),
    DatabaseService.instance.sectionsDetailed(),
    DatabaseService.instance.rows('stages', orderBy: 'position'),
  ]);
  void _refresh() => setState(() {});

  Future<void> _addGrade(List<Map<String, Object?>> stages) async {
    final name = TextEditingController();
    int? stageId = stages.isEmpty ? null : stages.first['id'] as int;
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: const Text('إضافة صف'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم الصف')),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(value: stageId, decoration: const InputDecoration(labelText: 'المرحلة'), items: stages.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']}'))).toList(), onChanged: (v) => update(() => stageId = v)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ'))],
    )));
    if (ok != true) return;
    if (name.text.trim().isEmpty || stageId == null) { if (mounted) showMessage(context, 'أدخل اسم الصف واختر المرحلة.', error: true); return; }
    try {
      await DatabaseService.instance.add('grades', {'stage_id': stageId, 'name': name.text.trim(), 'max_daily_lessons': 7, 'position': 99});
      _refresh(); widget.onChanged();
    } catch (e) { if (mounted) showMessage(context, 'تعذر إضافة الصف: $e', error: true); }
  }

  Future<void> _addSection(List<Map<String, Object?>> grades) async {
    final name = TextEditingController();
    int? gradeId = grades.isEmpty ? null : grades.first['id'] as int;
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: const Text('إضافة شعبة'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(value: gradeId, decoration: const InputDecoration(labelText: 'الصف'), items: grades.map((g) => DropdownMenuItem(value: g['id'] as int, child: Text('${g['name']}'))).toList(), onChanged: (v) => update(() => gradeId = v)),
        const SizedBox(height: 12), TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم الشعبة (أ، ب، ج...)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ'))],
    )));
    if (ok != true) return;
    if (name.text.trim().isEmpty || gradeId == null) { if (mounted) showMessage(context, 'اختر الصف واكتب اسم الشعبة.', error: true); return; }
    try {
      await DatabaseService.instance.add('sections', {'grade_id': gradeId, 'name': name.text.trim(), 'max_daily_lessons': 7});
      _refresh(); widget.onChanged();
    } catch (e) { if (mounted) showMessage(context, 'تعذر إضافة الشعبة. تحقق من عدم تكرار اسمها ضمن الصف نفسه. ($e)', error: true); }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: _load(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final grades = (snapshot.data![0] as List).cast<Map<String, Object?>>();
      final sections = (snapshot.data![1] as List).cast<Map<String, Object?>>();
      final stages = (snapshot.data![2] as List).cast<Map<String, Object?>>();
      return ListView(padding: const EdgeInsets.all(16), children: [
        pageHeading('الصفوف والشعب', 'أضف الصفوف والشعب حسب الهيكل الفعلي للمدرسة.', trailing: PopupMenuButton<String>(onSelected: (value) => value == 'grade' ? _addGrade(stages) : _addSection(grades), itemBuilder: (_) => const [PopupMenuItem(value: 'grade', child: Text('إضافة صف')), PopupMenuItem(value: 'section', child: Text('إضافة شعبة'))], child: const Icon(Icons.add_circle, size: 32, color: Color(0xFF2878C8)))),
        if (grades.isEmpty) emptyState(icon: Icons.school_outlined, title: 'لا توجد صفوف', message: 'أضف مرحلة دراسية ثم أنشئ الصف الأول.'),
        ...grades.map((grade) {
          final gradeSections = sections.where((s) => s['grade_id'] == grade['id']).toList();
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${grade['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))), Chip(label: Text('${gradeSections.length} شعبة')), IconButton(tooltip: 'حذف الصف', onPressed: () async { if (await confirmAction(context, 'حذف الصف', 'سيُرفض الحذف إذا كان الصف مرتبطاً بشعب أو بيانات أخرى. هل تريد المتابعة؟')) { try { await DatabaseService.instance.remove('grades', grade['id'] as int); _refresh(); widget.onChanged(); } catch (e) { if (context.mounted) showMessage(context, 'تعذر حذف الصف لوجود ارتباطات: $e', error: true); } } }, icon: const Icon(Icons.delete_outline, color: Colors.redAccent))]),
            if (gradeSections.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('لا توجد شعب مضافة لهذا الصف.', style: TextStyle(color: Colors.black54))),
            Wrap(spacing: 8, runSpacing: 8, children: gradeSections.map((s) => InputChip(label: Text('${s['section_name']}'), onDeleted: () async { if (await confirmAction(context, 'حذف الشعبة', 'سيتم حذف الشعبة إذا لم تمنع ارتباطات الجدول ذلك.')) { try { await DatabaseService.instance.remove('sections', s['id'] as int); _refresh(); widget.onChanged(); } catch (e) { if (context.mounted) showMessage(context, 'تعذر حذف الشعبة: $e', error: true); } } })).toList()),
            const SizedBox(height: 5), Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _addSection(grades), icon: const Icon(Icons.add), label: const Text('إضافة شعبة'))),
          ]))));
        }),
        const SizedBox(height: 8), OutlinedButton.icon(onPressed: () => _addGrade(stages), icon: const Icon(Icons.add), label: const Text('إضافة صف جديد')),
      ]);
    },
  );
}

class _SubjectsTab extends StatefulWidget {
  const _SubjectsTab({required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  Future<List<Map<String, Object?>>> _load() => DatabaseService.instance.rows('subjects', orderBy: 'name');
  Future<void> _editSubject([Map<String, Object?>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final code = TextEditingController(text: item?['code']?.toString() ?? '');
    final daily = TextEditingController(text: '${item?['max_daily_lessons'] ?? 2}');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(item == null ? 'إضافة مادة' : 'تعديل مادة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المادة')),
        const SizedBox(height: 10), TextField(controller: code, decoration: const InputDecoration(labelText: 'الرمز (اختياري)')),
        const SizedBox(height: 10), TextField(controller: daily, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد اليومي للشعبة')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
    ));
    if (ok != true) return;
    if (name.text.trim().isEmpty) { if (mounted) showMessage(context, 'اسم المادة مطلوب.', error: true); return; }
    final values = {'name': name.text.trim(), 'code': code.text.trim(), 'max_daily_lessons': int.tryParse(daily.text) ?? 2};
    try {
      if (item == null) await DatabaseService.instance.add('subjects', {...values, 'color': 4280391411, 'allow_same_day': 0});
      else await DatabaseService.instance.edit('subjects', item['id'] as int, values);
      setState(() {}); widget.onChanged();
    } catch (e) { if (mounted) showMessage(context, 'تعذر حفظ المادة؛ ربما يوجد اسم مكرر. $e', error: true); }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(future: _load(), builder: (context, snapshot) {
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final subjects = snapshot.data!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      pageHeading('المواد الدراسية', 'قائمة قابلة للتعديل. حدد عدد الحصص المطلوب لكل شعبة في تبويب الحصص المطلوبة.', trailing: IconButton(onPressed: () => _editSubject(), icon: const Icon(Icons.add_circle, size: 32, color: Color(0xFF2878C8)))),
      if (subjects.isEmpty) emptyState(icon: Icons.menu_book_outlined, title: 'لا توجد مواد', message: 'أضف المواد التي تدرسها المدرسة.'),
      ...subjects.map((s) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFE4EEF9), child: const Icon(Icons.menu_book, color: Color(0xFF2878C8))),
        title: Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('الرمز: ${((s['code'] as String?)?.isNotEmpty ?? false) ? s['code'] : '—'}  •  الحد اليومي الافتراضي: ${s['max_daily_lessons']}'),
        trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') _editSubject(s); if (v == 'delete' && await confirmAction(context, 'حذف المادة', 'قد يمنع وجود حصص أو متطلبات مرتبطة حذف هذه المادة.')) { try { await DatabaseService.instance.remove('subjects', s['id'] as int); setState(() {}); widget.onChanged(); } catch (e) { if (context.mounted) showMessage(context, 'تعذر حذف المادة بسبب الارتباطات: $e', error: true); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]),
      )))),
      const SizedBox(height: 8), FilledButton.icon(onPressed: () => _editSubject(), icon: const Icon(Icons.add), label: const Text('إضافة مادة')),
    ]);
  });
}

class _TeachersTab extends StatefulWidget {
  const _TeachersTab({required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<_TeachersTab> {
  Future<List<dynamic>> _load() async => Future.wait([
    DatabaseService.instance.rows('teachers', orderBy: 'name'),
    DatabaseService.instance.rows('subjects', orderBy: 'name'),
    DatabaseService.instance.rows('teacher_subjects'),
  ]);

  Future<void> _editTeacher(List<Map<String, Object?>> subjects, [Map<String, Object?>? teacher]) async {
    final name = TextEditingController(text: teacher?['name']?.toString() ?? '');
    final code = TextEditingController(text: teacher?['code']?.toString() ?? '');
    final weekly = TextEditingController(text: '${teacher?['weekly_load'] ?? 24}');
    final daily = TextEditingController(text: '${teacher?['max_daily_lessons'] ?? 6}');
    final consecutive = TextEditingController(text: '${teacher?['max_consecutive_lessons'] ?? 4}');
    final qualificationRows = await DatabaseService.instance.rows('teacher_subjects');
    final selected = <int>{
      for (final q in qualificationRows)
        if (teacher != null && q['teacher_id'] == teacher['id']) q['subject_id'] as int,
    };
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text(teacher == null ? 'إضافة معلم' : 'تعديل بيانات المعلم'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المعلم الكامل')),
        const SizedBox(height: 10), TextField(controller: code, decoration: const InputDecoration(labelText: 'الرمز (اختياري)')),
        const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: weekly, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'النصاب الأسبوعي'))), const SizedBox(width: 8), Expanded(child: TextField(controller: daily, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد اليومي')))]),
        const SizedBox(height: 10), TextField(controller: consecutive, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أقصى حصص متتالية')),
        const SizedBox(height: 14), const Align(alignment: Alignment.centerRight, child: Text('المواد المؤهل لتدريسها', style: TextStyle(fontWeight: FontWeight.bold))),
        ...subjects.map((s) => CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, value: selected.contains(s['id']), title: Text('${s['name']}'), onChanged: (value) => update(() { if (value == true) { selected.add(s['id'] as int); } else { selected.remove(s['id']); } }))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
    )));
    if (result != true) return;
    if (name.text.trim().isEmpty) { if (mounted) showMessage(context, 'اسم المعلم مطلوب.', error: true); return; }
    final values = {'name': name.text.trim(), 'code': code.text.trim(), 'weekly_load': int.tryParse(weekly.text) ?? 24,
      'max_daily_lessons': int.tryParse(daily.text) ?? 6, 'max_consecutive_lessons': int.tryParse(consecutive.text) ?? 4, 'notes': teacher?['notes'] ?? ''};
    try {
      final db = await DatabaseService.instance.database;
      await db.transaction((txn) async {
        int id;
        if (teacher == null) { id = await txn.insert('teachers', values); }
        else { id = teacher['id'] as int; await txn.update('teachers', values, where: 'id=?', whereArgs: [id]); }
        await txn.delete('teacher_subjects', where: 'teacher_id=?', whereArgs: [id]);
        for (final subjectId in selected) { await txn.insert('teacher_subjects', {'teacher_id': id, 'subject_id': subjectId}); }
      });
      if (mounted) setState(() {}); widget.onChanged();
    } catch (e) { if (mounted) showMessage(context, 'تعذر حفظ بيانات المعلم: $e', error: true); }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: _load(), builder: (context, snapshot) {
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final teachers = (snapshot.data![0] as List).cast<Map<String, Object?>>();
    final subjects = (snapshot.data![1] as List).cast<Map<String, Object?>>();
    final quals = (snapshot.data![2] as List).cast<Map<String, Object?>>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      pageHeading('المعلمون', 'سجّل النصاب والمواد المؤهل كل معلم لتدريسها.', trailing: IconButton(onPressed: () => _editTeacher(subjects), icon: const Icon(Icons.person_add_alt_1, size: 30, color: Color(0xFF2878C8)))),
      if (teachers.isEmpty) emptyState(icon: Icons.co_present_outlined, title: 'لا يوجد معلمون بعد', message: 'أضف المعلمين وحدد المواد المؤهلين لتدريسها قبل الجدولة التلقائية.'),
      ...teachers.map((t) {
        final ids = quals.where((q) => q['teacher_id'] == t['id']).map((q) => q['subject_id']).toSet();
        final names = subjects.where((s) => ids.contains(s['id'])).map((s) => '${s['name']}').join('، ');
        return Padding(padding: const EdgeInsets.only(bottom: 9), child: Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFFE7F3EE), child: const Icon(Icons.person_outline, color: Color(0xFF16845B))),
          title: Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('النصاب: ${t['weekly_load']} أسبوعياً • يومي: ${t['max_daily_lessons']}\nالمواد: ${names.isEmpty ? 'لم تحدد' : names}', maxLines: 3, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') _editTeacher(subjects, t); if (v == 'delete' && await confirmAction(context, 'حذف المعلم', 'قد تصبح حصصه بلا معلم. هل تريد الحذف؟')) { try { await DatabaseService.instance.remove('teachers', t['id'] as int); setState(() {}); widget.onChanged(); } catch (e) { if (context.mounted) showMessage(context, 'تعذر حذف المعلم: $e', error: true); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]),
        )));
      }),
      const SizedBox(height: 8), FilledButton.icon(onPressed: () => _editTeacher(subjects), icon: const Icon(Icons.add), label: const Text('إضافة معلم')),
    ]);
  });
}

class _RequirementsTab extends StatefulWidget {
  const _RequirementsTab({required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<_RequirementsTab> createState() => _RequirementsTabState();
}

class _RequirementsTabState extends State<_RequirementsTab> {
  Future<List<dynamic>> _load() async => Future.wait([
    DatabaseService.instance.sectionsDetailed(), DatabaseService.instance.rows('subjects', orderBy: 'name'), DatabaseService.instance.requirementsDetailed(),
  ]);
  Future<void> _editRequirement(List<Map<String, Object?>> sections, List<Map<String, Object?>> subjects, [Map<String, Object?>? existing]) async {
    int? sectionId = existing?['section_id'] as int? ?? (sections.isEmpty ? null : sections.first['id'] as int);
    int? subjectId = existing?['subject_id'] as int? ?? (subjects.isEmpty ? null : subjects.first['id'] as int);
    final count = TextEditingController(text: '${existing?['weekly_lessons'] ?? 5}');
    final maxDaily = TextEditingController(text: '${existing?['max_daily_lessons'] ?? 2}');
    bool allowSameDay = (existing?['allow_same_day'] as int? ?? 0) == 1;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text(existing == null ? 'تحديد حصص مادة لشعبة' : 'تعديل الحصص المطلوبة'),
      content: SizedBox(width: 410, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(value: sectionId, isExpanded: true, decoration: const InputDecoration(labelText: 'الشعبة'), items: sections.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['grade_name']} - ${s['section_name']}'))).toList(), onChanged: existing == null ? (v) => update(() => sectionId = v) : null),
        const SizedBox(height: 10), DropdownButtonFormField<int>(value: subjectId, isExpanded: true, decoration: const InputDecoration(labelText: 'المادة'), items: subjects.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']}'))).toList(), onChanged: existing == null ? (v) => update(() => subjectId = v) : null),
        const SizedBox(height: 10), TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الحصص الأسبوعية المطلوبة')),
        const SizedBox(height: 10), TextField(controller: maxDaily, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أقصى عدد يومي للمادة')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('السماح بتكرار المادة في اليوم'), value: allowSameDay, onChanged: (v) => update(() => allowSameDay = v)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
    )));
    if (ok != true) return;
    if (sectionId == null || subjectId == null) { if (mounted) showMessage(context, 'اختر الشعبة والمادة.', error: true); return; }
    final values = {'section_id': sectionId, 'subject_id': subjectId, 'weekly_lessons': (int.tryParse(count.text) ?? 0).clamp(0, 60), 'max_daily_lessons': (int.tryParse(maxDaily.text) ?? 2).clamp(1, 10), 'allow_same_day': allowSameDay ? 1 : 0};
    try {
      if (existing == null) {
        final db = await DatabaseService.instance.database;
        final old = await db.query('section_subject_requirements', where: 'section_id=? AND subject_id=?', whereArgs: [sectionId, subjectId], limit: 1);
        if (old.isEmpty) await DatabaseService.instance.add('section_subject_requirements', values);
        else await DatabaseService.instance.edit('section_subject_requirements', old.first['id'] as int, values);
      } else {
        await DatabaseService.instance.edit('section_subject_requirements', existing['id'] as int, values);
      }
      setState(() {}); widget.onChanged();
    } catch (e) { if (mounted) showMessage(context, 'تعذر حفظ المتطلبات: $e', error: true); }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: _load(), builder: (context, snapshot) {
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final sections = (snapshot.data![0] as List).cast<Map<String, Object?>>();
    final subjects = (snapshot.data![1] as List).cast<Map<String, Object?>>();
    final requirements = (snapshot.data![2] as List).cast<Map<String, Object?>>();
    final total = requirements.fold<int>(0, (sum, r) => sum + ((r['weekly_lessons'] as num?)?.toInt() ?? 0));
    return ListView(padding: const EdgeInsets.all(16), children: [
      pageHeading('الحصص المطلوبة', 'هذا التحديد هو أساس احتساب الاكتمال ومحرك الجدولة التلقائية.', trailing: IconButton(onPressed: () => _editRequirement(sections, subjects), icon: const Icon(Icons.add_circle, size: 32, color: Color(0xFF2878C8)))),
      Card(child: ListTile(leading: const Icon(Icons.calculate_outlined, color: Color(0xFF2878C8)), title: const Text('إجمالي الحصص الأسبوعية المطلوبة'), trailing: Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 12),
      if (sections.isEmpty || subjects.isEmpty) emptyState(icon: Icons.info_outline, title: 'أكمل البيانات أولاً', message: 'أضف صفاً وشعبة ومادة واحدة على الأقل لتسجيل متطلبات الحصص.'),
      if (requirements.isEmpty && sections.isNotEmpty && subjects.isNotEmpty) emptyState(icon: Icons.rule_folder_outlined, title: 'لم تسجل متطلبات بعد', message: 'اضغط إضافة لتحديد عدد الحصص الأسبوعية لكل مادة ولكل شعبة.'),
      ...requirements.map((r) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFE8F1FB), child: Icon(Icons.fact_check_outlined, color: Color(0xFF2878C8))),
        title: Text('${r['grade_name']} - ${r['section_name']} / ${r['subject_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('أسبوعياً: ${r['weekly_lessons']} • يومياً: ${r['max_daily_lessons']} • تكرار في اليوم: ${r['allow_same_day'] == 1 ? 'مسموح' : 'غير مسموح'}'),
        onTap: () => _editRequirement(sections, subjects, r),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () async { if (await confirmAction(context, 'حذف المتطلب', 'سيتم حذف متطلب هذه المادة للشعبة.')) { await DatabaseService.instance.remove('section_subject_requirements', r['id'] as int); setState(() {}); widget.onChanged(); } }),
      )))),
      if (sections.isNotEmpty && subjects.isNotEmpty) FilledButton.icon(onPressed: () => _editRequirement(sections, subjects), icon: const Icon(Icons.add), label: const Text('إضافة متطلب حصص')),
    ]);
  });
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _school = TextEditingController();
  final _directorate = TextEditingController();
  final _stage = TextEditingController();
  bool _settingsLoaded = false;
  Future<List<dynamic>> _load() async => Future.wait([
    DatabaseService.instance.getSettings(), DatabaseService.instance.rows('academic_years', orderBy: 'created_at DESC'),
    DatabaseService.instance.rows('school_days', orderBy: 'position'), DatabaseService.instance.rows('time_slots', orderBy: 'position'),
  ]);

  Future<void> _saveSettings() async {
    await DatabaseService.instance.saveSettings({'school_name': _school.text.trim().isEmpty ? 'مدرستي' : _school.text.trim(), 'directorate': _directorate.text.trim(), 'stage': _stage.text.trim()});
    if (mounted) showMessage(context, 'تم حفظ إعدادات المدرسة.'); widget.onChanged(); setState(() {});
  }

  Future<void> _addYear() async {
    final name = TextEditingController(text: '${DateTime.now().year}-${DateTime.now().year + 1}');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('عام دراسي جديد'), content: TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم العام الدراسي')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء'))]));
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final id = await DatabaseService.instance.add('academic_years', {'name': name.text.trim(), 'is_active': 0, 'created_at': DateTime.now().toIso8601String()});
      await DatabaseService.instance.setActiveYear(id);
      if (mounted) showMessage(context, 'تم إنشاء العام وتفعيله مع الاحتفاظ بالأعوام السابقة.');
      setState(() {}); widget.onChanged();
    } catch (e) { if (mounted) showMessage(context, 'تعذر إنشاء العام؛ تحقق من عدم تكرار الاسم. $e', error: true); }
  }

  Future<void> _editSlot([Map<String, Object?>? slot]) async {
    final name = TextEditingController(text: slot?['name']?.toString() ?? 'الحصة الجديدة');
    final start = TextEditingController(text: slot?['start_time']?.toString() ?? '12:00');
    final end = TextEditingController(text: slot?['end_time']?.toString() ?? '12:45');
    String kind = slot?['kind']?.toString() ?? 'lesson';
    final available = (slot?['is_available'] as int? ?? 1) == 1;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text(slot == null ? 'إضافة فترة' : 'تعديل الفترة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الفترة')),
        const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: start, decoration: const InputDecoration(labelText: 'البداية HH:MM'))), const SizedBox(width: 8), Expanded(child: TextField(controller: end, decoration: const InputDecoration(labelText: 'النهاية HH:MM')))]),
        const SizedBox(height: 10), DropdownButtonFormField<String>(value: kind, decoration: const InputDecoration(labelText: 'نوع الفترة'), items: const [DropdownMenuItem(value: 'lesson', child: Text('حصة دراسية')), DropdownMenuItem(value: 'break', child: Text('استراحة')), DropdownMenuItem(value: 'activity', child: Text('نشاط')), DropdownMenuItem(value: 'unavailable', child: Text('غير متاحة'))], onChanged: (v) => update(() => kind = v ?? 'lesson')),
        const SizedBox(height: 6), Text('لن تُدرج الاستراحات والأنشطة ضمن حصص الجدولة.', style: Theme.of(context).textTheme.bodySmall),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
    )));
    if (ok != true) return;
    final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (!timePattern.hasMatch(start.text) || !timePattern.hasMatch(end.text) || start.text.compareTo(end.text) >= 0 || name.text.trim().isEmpty) {
      if (mounted) showMessage(context, 'تحقق من اسم الفترة والوقت بصيغة HH:MM وأن النهاية بعد البداية.', error: true); return;
    }
    try {
      final values = {'name': name.text.trim(), 'start_time': start.text, 'end_time': end.text, 'kind': kind, 'is_available': kind == 'lesson' ? (available ? 1 : 0) : 0, 'position': slot?['position'] ?? 99};
      if (slot == null) await DatabaseService.instance.add('time_slots', values);
      else await DatabaseService.instance.edit('time_slots', slot['id'] as int, values);
      setState(() {}); widget.onChanged();
    } catch (e) { if (mounted) showMessage(context, 'تعذر حفظ الفترة: $e', error: true); }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(future: _load(), builder: (context, snapshot) {
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final settings = (snapshot.data![0] as Map).cast<String, Object?>();
    final years = (snapshot.data![1] as List).cast<Map<String, Object?>>();
    final days = (snapshot.data![2] as List).cast<Map<String, Object?>>();
    final slots = (snapshot.data![3] as List).cast<Map<String, Object?>>();
    if (!_settingsLoaded) {
      _school.text = settings['school_name']?.toString() ?? 'مدرستي';
      _directorate.text = settings['directorate']?.toString() ?? '';
      _stage.text = settings['stage']?.toString() ?? 'الابتدائية';
      _settingsLoaded = true;
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      pageHeading('إعدادات المدرسة', 'تُحفظ الإعدادات والفترات محلياً على الجهاز.'),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        TextField(controller: _school, decoration: const InputDecoration(labelText: 'اسم المدرسة')),
        const SizedBox(height: 10), TextField(controller: _directorate, decoration: const InputDecoration(labelText: 'المديرية أو الإدارة (اختياري)')),
        const SizedBox(height: 10), TextField(controller: _stage, decoration: const InputDecoration(labelText: 'المرحلة الدراسية')),
        const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: _saveSettings, icon: const Icon(Icons.save_outlined), label: const Text('حفظ الإعدادات'))),
      ]))),
      const SizedBox(height: 18),
      Row(children: [const Expanded(child: Text('الأعوام الدراسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), IconButton(onPressed: _addYear, icon: const Icon(Icons.add_circle, color: Color(0xFF2878C8)))]),
      ...years.map((year) => Card(child: RadioListTile<int>(value: year['id'] as int, groupValue: year['is_active'] == 1 ? year['id'] as int : null, onChanged: (id) async { if (id != null) { await DatabaseService.instance.setActiveYear(id); setState(() {}); widget.onChanged(); } }, title: Text('${year['name']}'), subtitle: Text(year['is_active'] == 1 ? 'العام النشط' : 'أرشيف عام سابق'), secondary: year['is_active'] == 1 ? const Icon(Icons.check_circle, color: Color(0xFF16845B)) : null))),
      const SizedBox(height: 18),
      const Text('أيام الدوام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Card(child: Column(children: days.map((day) => SwitchListTile(
        value: day['is_active'] == 1, title: Text('${day['name']}'),
        onChanged: (v) async {
          if (!v) {
            final version = await DatabaseService.instance.activeVersionId(await DatabaseService.instance.activeYearId());
            final entries = await DatabaseService.instance.entriesDetailed(versionId: version);
            final related = entries.where((e) => e['day_id'] == day['id']).length;
            if (related > 0 && !await confirmAction(context, 'تعطيل يوم يحتوي حصصاً', 'يوجد $related حصة في هذا اليوم. سيظل الجدول محفوظاً لكنه سيظهر كتعارض يحتاج مراجعة. متابعة؟')) return;
          }
          await DatabaseService.instance.edit('school_days', day['id'] as int, {'is_active': v ? 1 : 0}); setState(() {}); widget.onChanged();
        },
      )).toList())),
      const SizedBox(height: 18),
      Row(children: [const Expanded(child: Text('أوقات الحصص والاستراحات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), IconButton(onPressed: () => _editSlot(), icon: const Icon(Icons.add_circle, color: Color(0xFF2878C8)))]),
      ...slots.map((slot) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Card(child: ListTile(
        leading: Icon(slot['kind'] == 'lesson' ? Icons.access_time : Icons.coffee_outlined, color: slot['kind'] == 'lesson' ? const Color(0xFF2878C8) : Colors.orange),
        title: Text('${slot['name']}'), subtitle: Text('${slot['start_time']} – ${slot['end_time']} • ${_kindLabel('${slot['kind']}')}'),
        trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') _editSlot(slot); if (v == 'delete' && await confirmAction(context, 'حذف الفترة', 'إذا كانت الفترة مستخدمة في الجدول فلن يتم حذفها.')) { try { await DatabaseService.instance.remove('time_slots', slot['id'] as int); setState(() {}); } catch (e) { if (context.mounted) showMessage(context, 'تعذر حذف الفترة المرتبطة بجدول: $e', error: true); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]),
      )))),
      const SizedBox(height: 8),
      const Text('ملاحظة: عند تعطيل يوم يحتوي حصصاً، لا تُحذف الحصص تلقائياً حفاظاً على بيانات الجدول.', style: TextStyle(color: Colors.black54)),
    ]);
  });

  String _kindLabel(String kind) => switch (kind) {
    'lesson' => 'حصة دراسية', 'break' => 'استراحة', 'activity' => 'نشاط', _ => 'غير متاحة',
  };
}
