/// محرك جدولة مستقل يستخدم البحث مع ترتيب المسائل الأكثر تقييداً أولاً.
/// يعيد نتيجة مؤقتة ولا يكتب في قاعدة البيانات؛ الاعتماد والحفظ مسؤولية الواجهة.
class SchedulerResult {
  const SchedulerResult({
    required this.placements,
    required this.unscheduled,
    required this.requestedCount,
    required this.exploredNodes,
    required this.searchLimitReached,
  });
  final List<Map<String, Object?>> placements;
  final List<String> unscheduled;
  final int requestedCount;
  final int exploredNodes;
  final bool searchLimitReached;
  bool get complete => placements.length == requestedCount && unscheduled.isEmpty;
}

class _LessonTask {
  _LessonTask({required this.section, required this.requirement, required this.teachers, required this.index});
  final Map<String, Object?> section;
  final Map<String, Object?> requirement;
  final List<Map<String, Object?>> teachers;
  final int index;

  int get sectionId => _integer(section['id'] ?? requirement['section_id']);
  int get subjectId => _integer(requirement['subject_id']);
  String get label => '${section['section_name'] ?? section['name'] ?? 'الشعبة $sectionId'} / ${requirement['subject_name'] ?? 'المادة $subjectId'}';
}

class AutoSchedulerService {
  const AutoSchedulerService({this.nodeLimit = 30000});
  final int nodeLimit;

  SchedulerResult generate({
    required List<Map<String, Object?>> sections,
    required List<Map<String, Object?>> requirements,
    required List<Map<String, Object?>> teachers,
    required List<Map<String, Object?>> qualifications,
    required List<Map<String, Object?>> days,
    required List<Map<String, Object?>> slots,
    List<Map<String, Object?>> teacherAvailability = const [],
  }) {
    final enabledDays = days.where((d) => _integer(d['is_active'], fallback: 1) == 1).toList()
      ..sort((a, b) => _integer(a['position']).compareTo(_integer(b['position'])));
    final lessonSlots = slots.where((s) => s['kind'] == 'lesson' && _integer(s['is_available'], fallback: 1) == 1).toList()
      ..sort((a, b) => _integer(a['position']).compareTo(_integer(b['position'])));
    final sectionById = {for (final s in sections) _integer(s['id']): s};
    final teacherById = {for (final t in teachers) _integer(t['id']): t};
    final qualifiedIds = <int, List<int>>{};
    for (final qualification in qualifications) {
      final subjectId = _integer(qualification['subject_id']);
      final teacherId = _integer(qualification['teacher_id']);
      (qualifiedIds[subjectId] ??= []).add(teacherId);
    }
    final unavailable = <String>{
      for (final item in teacherAvailability)
        if (_integer(item['is_available'], fallback: 1) == 0)
          '${_integer(item['teacher_id'])}:${_integer(item['day_id'])}:${_integer(item['slot_id'])}',
    };
    final requestedCount = requirements.fold<int>(0, (sum, r) => sum + _integer(r['weekly_lessons']));
    final tasks = <_LessonTask>[];
    final unscheduled = <String>[];
    var taskIndex = 0;
    for (final requirement in requirements) {
      final count = _integer(requirement['weekly_lessons']);
      if (count <= 0) continue;
      final sectionId = _integer(requirement['section_id']);
      final section = sectionById[sectionId];
      if (section == null) {
        unscheduled.add('الشعبة ذات المعرف $sectionId غير موجودة في إعدادات الجدولة.');
        continue;
      }
      final teacherList = (qualifiedIds[_integer(requirement['subject_id'])] ?? const <int>[])
          .map((id) => teacherById[id]).whereType<Map<String, Object?>>().toList();
      if (teacherList.isEmpty) {
        unscheduled.add('${section['section_name'] ?? section['name']} / ${requirement['subject_name'] ?? 'المادة'}: لا يوجد معلم مؤهل مسجل لهذه المادة.');
        continue;
      }
      if (enabledDays.isEmpty || lessonSlots.isEmpty) {
        unscheduled.add('${section['section_name'] ?? section['name']}: لا توجد أيام دوام وفترات تدريس متاحة.');
        continue;
      }
      for (var i = 0; i < count; i++) {
        tasks.add(_LessonTask(section: section, requirement: requirement, teachers: teacherList, index: taskIndex++));
      }
    }

    // القيود ذات خيارات المعلمين الأقل تعالج أولاً. الترتيب مستقر لتكرارية النتائج.
    tasks.sort((a, b) {
      final teacherCompare = a.teachers.length.compareTo(b.teachers.length);
      if (teacherCompare != 0) return teacherCompare;
      final sectionCompare = a.sectionId.compareTo(b.sectionId);
      if (sectionCompare != 0) return sectionCompare;
      return a.subjectId.compareTo(b.subjectId);
    });

    final sectionCells = <String>{};
    final teacherCells = <String>{};
    final teacherWeekly = <int, int>{};
    final teacherDaily = <String, int>{};
    final sectionDaily = <String, int>{};
    final subjectDaily = <String, int>{};
    final teacherDaySlotPositions = <String, List<int>>{};
    final placed = <Map<String, Object?>>[];
    var best = <Map<String, Object?>>[];
    var nodes = 0;
    var limitReached = false;
    var foundComplete = false;

    String dayKey(int teacherId, int dayId) => '$teacherId:$dayId';
    String countKey(int id, int dayId) => '$id:$dayId';
    String subjectKey(int sectionId, int subjectId, int dayId) => '$sectionId:$subjectId:$dayId';

    bool tryPlace(_LessonTask task, Map<String, Object?> teacher, Map<String, Object?> day, Map<String, Object?> slot) {
      final sectionId = task.sectionId;
      final teacherId = _integer(teacher['id']);
      final dayId = _integer(day['id']);
      final slotId = _integer(slot['id']);
      final subjectId = task.subjectId;
      final cell = '$sectionId:$dayId:$slotId';
      final teacherCell = '$teacherId:$dayId:$slotId';
      if (sectionCells.contains(cell) || teacherCells.contains(teacherCell)) return false;
      if (unavailable.contains('$teacherId:$dayId:$slotId')) return false;
      final teacherWeeklyLimit = _integer(teacher['weekly_load'], fallback: 24);
      if (teacherWeeklyLimit > 0 && (teacherWeekly[teacherId] ?? 0) >= teacherWeeklyLimit) return false;
      final teacherDayKey = dayKey(teacherId, dayId);
      final teacherDailyLimit = _integer(teacher['max_daily_lessons'], fallback: 6);
      if (teacherDailyLimit > 0 && (teacherDaily[teacherDayKey] ?? 0) >= teacherDailyLimit) return false;
      final sectionDayKey = countKey(sectionId, dayId);
      final sectionLimit = _integer(task.section['max_daily_lessons'], fallback: 7);
      if (sectionLimit > 0 && (sectionDaily[sectionDayKey] ?? 0) >= sectionLimit) return false;
      final sDailyKey = subjectKey(sectionId, subjectId, dayId);
      final allowSameDay = _integer(task.requirement['allow_same_day']) == 1;
      final subjectLimit = allowSameDay
          ? _integer(task.requirement['max_daily_lessons'], fallback: 2)
          : 1;
      if ((subjectDaily[sDailyKey] ?? 0) >= (subjectLimit <= 0 ? 1 : subjectLimit)) return false;

      // الحد الأقصى للحصص المتتالية للمعلم، على ترتيب فترات التدريس الفعلية.
      final maxConsecutive = _integer(teacher['max_consecutive_lessons'], fallback: 0);
      if (maxConsecutive > 0) {
        final newPositions = [...(teacherDaySlotPositions[teacherDayKey] ?? <int>[]), _integer(slot['position'])]
          ..sort();
        var run = 1;
        var longest = 1;
        for (var i = 1; i < newPositions.length; i++) {
          if (newPositions[i] == newPositions[i - 1] + 1) {
            run++;
          } else {
            run = 1;
          }
          if (run > longest) longest = run;
        }
        if (longest > maxConsecutive) return false;
      }

      sectionCells.add(cell);
      teacherCells.add(teacherCell);
      teacherWeekly[teacherId] = (teacherWeekly[teacherId] ?? 0) + 1;
      teacherDaily[teacherDayKey] = (teacherDaily[teacherDayKey] ?? 0) + 1;
      sectionDaily[sectionDayKey] = (sectionDaily[sectionDayKey] ?? 0) + 1;
      subjectDaily[sDailyKey] = (subjectDaily[sDailyKey] ?? 0) + 1;
      (teacherDaySlotPositions[teacherDayKey] ??= <int>[]).add(_integer(slot['position']));
      placed.add({
        'section_id': sectionId, 'subject_id': subjectId, 'teacher_id': teacherId,
        'day_id': dayId, 'slot_id': slotId, 'room_id': null,
      });
      return true;
    }

    void undo(_LessonTask task, Map<String, Object?> teacher, Map<String, Object?> day, Map<String, Object?> slot) {
      final sectionId = task.sectionId;
      final teacherId = _integer(teacher['id']);
      final dayId = _integer(day['id']);
      final slotId = _integer(slot['id']);
      final subjectId = task.subjectId;
      final cell = '$sectionId:$dayId:$slotId';
      final teacherCell = '$teacherId:$dayId:$slotId';
      final teacherDayKey = dayKey(teacherId, dayId);
      final sectionDayKey = countKey(sectionId, dayId);
      final sDailyKey = subjectKey(sectionId, subjectId, dayId);
      sectionCells.remove(cell);
      teacherCells.remove(teacherCell);
      teacherWeekly[teacherId] = (teacherWeekly[teacherId] ?? 1) - 1;
      teacherDaily[teacherDayKey] = (teacherDaily[teacherDayKey] ?? 1) - 1;
      sectionDaily[sectionDayKey] = (sectionDaily[sectionDayKey] ?? 1) - 1;
      subjectDaily[sDailyKey] = (subjectDaily[sDailyKey] ?? 1) - 1;
      teacherDaySlotPositions[teacherDayKey]?.remove(_integer(slot['position']));
      placed.removeLast();
    }

    void search(int index) {
      if (foundComplete || limitReached) return;
      nodes++;
      if (placed.length > best.length) best = placed.map((e) => Map<String, Object?>.from(e)).toList();
      if (placed.length == tasks.length) { foundComplete = true; return; }
      if (nodes >= nodeLimit) { limitReached = true; return; }
      if (index >= tasks.length) return;

      final task = tasks[index];
      final orderedTeachers = [...task.teachers]..sort((a, b) =>
          (teacherWeekly[_integer(a['id'])] ?? 0).compareTo(teacherWeekly[_integer(b['id'])] ?? 0));
      for (final teacher in orderedTeachers) {
        for (final day in enabledDays) {
          for (final slot in lessonSlots) {
            if (tryPlace(task, teacher, day, slot)) {
              search(index + 1);
              undo(task, teacher, day, slot);
              if (foundComplete || limitReached) return;
            }
          }
        }
      }
      // تجاوز هذه الحصة يسمح بالحصول على أفضل جدول جزئي بدلاً من فقدان الحل كله.
      search(index + 1);
    }

    search(0);
    final placedCounts = <String, int>{};
    for (final p in best) {
      final key = '${p['section_id']}:${p['subject_id']}';
      placedCounts[key] = (placedCounts[key] ?? 0) + 1;
    }
    for (final requirement in requirements) {
      final sectionId = _integer(requirement['section_id']);
      final subjectId = _integer(requirement['subject_id']);
      final required = _integer(requirement['weekly_lessons']);
      final completed = placedCounts['$sectionId:$subjectId'] ?? 0;
      for (var n = completed; n < required; n++) {
        final section = sectionById[sectionId];
        final label = '${section?['section_name'] ?? section?['name'] ?? 'الشعبة $sectionId'} / ${requirement['subject_name'] ?? 'المادة $subjectId'}';
        final teacherOptions = qualifiedIds[subjectId] ?? const <int>[];
        final reason = teacherOptions.isEmpty
            ? 'لا يوجد معلم مؤهل.'
            : 'لم يعثر البحث على فترة ومعلم يحققان القيود المتاحة؛ قد تكون القيود متعارضة أو حد البحث غير كافٍ.';
        final message = '$label: الحصة ${n + 1} غير موزعة — $reason';
        if (!unscheduled.contains(message)) unscheduled.add(message);
      }
    }
    return SchedulerResult(
      placements: best,
      unscheduled: unscheduled,
      requestedCount: requestedCount,
      exploredNodes: nodes,
      searchLimitReached: limitReached,
    );
  }
}

int _integer(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}
