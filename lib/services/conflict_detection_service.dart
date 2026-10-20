/// خدمة مستقلة لفحص الجدول؛ لا تعتمد على واجهات Flutter أو قاعدة البيانات مباشرة.
class ConflictIssue {
  const ConflictIssue({
    required this.type,
    required this.severity,
    required this.message,
    this.sectionId,
    this.teacherId,
    this.dayId,
    this.slotId,
    this.subjectId,
    this.suggestion,
  });

  final String type;
  final String severity; // خطأ مانع | تحذير | ملاحظة
  final String message;
  final int? sectionId;
  final int? teacherId;
  final int? dayId;
  final int? slotId;
  final int? subjectId;
  final String? suggestion;
}

class ConflictDetectionService {
  const ConflictDetectionService();

  List<ConflictIssue> scan({
    required List<Map<String, Object?>> entries,
    List<Map<String, Object?>> requirements = const [],
    List<Map<String, Object?>> slots = const [],
    List<Map<String, Object?>> teachers = const [],
    List<Map<String, Object?>> qualifications = const [],
    List<Map<String, Object?>> days = const [],
    bool enforceQualifications = true,
  }) {
    final issues = <ConflictIssue>[];
    final sectionCells = <String, Map<String, Object?>>{};
    final teacherCells = <String, Map<String, Object?>>{};
    final roomCells = <String, Map<String, Object?>>{};
    final slotById = {for (final s in slots) _int(s['id']): s};
    final teacherById = {for (final t in teachers) _int(t['id']): t};
    final qualified = <String>{
      for (final q in qualifications) '${_int(q['teacher_id'])}:${_int(q['subject_id'])}',
    };
    final inactiveDays = <int>{for (final d in days) if (_int(d['is_active'], fallback: 1) == 0) _int(d['id'])};

    // تداخل الأوقات نفسها خطأ في إعداد الفترات حتى قبل توزيع الحصص.
    for (var i = 0; i < slots.length; i++) {
      final a = slots[i];
      final aStart = _minutes(a['start_time']);
      final aEnd = _minutes(a['end_time']);
      if (aStart == null || aEnd == null || aEnd <= aStart) continue;
      for (var j = i + 1; j < slots.length; j++) {
        final b = slots[j];
        final bStart = _minutes(b['start_time']);
        final bEnd = _minutes(b['end_time']);
        if (bStart == null || bEnd == null || bEnd <= bStart) continue;
        if (aStart < bEnd && bStart < aEnd) {
          issues.add(ConflictIssue(
            type: 'تداخل أوقات الفترات', severity: 'خطأ مانع',
            message: 'الفترتان ${a['name'] ?? a['id']} و${b['name'] ?? b['id']} متداخلتان زمنياً.',
            slotId: _int(b['id']), suggestion: 'عدّل بداية أو نهاية إحدى الفترتين حتى لا تتداخلا.',
          ));
        }
      }
    }

    for (final entry in entries) {
      final sectionId = _int(entry['section_id']);
      final teacherId = _nullableInt(entry['teacher_id']);
      final subjectId = _int(entry['subject_id']);
      final dayId = _int(entry['day_id']);
      final slotId = _int(entry['slot_id']);
      final roomId = _nullableInt(entry['room_id']);
      final key = '$dayId:$slotId';
      if (inactiveDays.contains(dayId)) {
        issues.add(ConflictIssue(
          type: 'يوم غير مفعل', severity: 'خطأ مانع',
          message: 'توجد حصة في يوم تم تعطيله من إعدادات المدرسة.',
          sectionId: sectionId, teacherId: teacherId, dayId: dayId, slotId: slotId, subjectId: subjectId,
          suggestion: 'انقل الحصة إلى يوم دوام فعّال أو أعد تفعيل اليوم.',
        ));
      }
      final sectionKey = '$sectionId:$key';
      final previousSection = sectionCells[sectionKey];
      if (previousSection != null && _int(previousSection['id']) != _int(entry['id'])) {
        issues.add(ConflictIssue(
          type: 'تعارض الشعبة', severity: 'خطأ مانع',
          message: 'الشعبة ${entry['section_name'] ?? sectionId} لديها أكثر من حصة في الفترة نفسها.',
          sectionId: sectionId, dayId: dayId, slotId: slotId,
          suggestion: 'انقل إحدى الحصتين إلى فترة فارغة.',
        ));
      } else {
        sectionCells[sectionKey] = entry;
      }

      if (teacherId != null) {
        final teacherKey = '$teacherId:$key';
        final previousTeacher = teacherCells[teacherKey];
        if (previousTeacher != null && _int(previousTeacher['id']) != _int(entry['id'])) {
          issues.add(ConflictIssue(
            type: 'تعارض المعلم', severity: 'خطأ مانع',
            message: 'المعلم ${entry['teacher_name'] ?? teacherId} مكلّف بأكثر من حصة في الوقت نفسه.',
            sectionId: sectionId, teacherId: teacherId, dayId: dayId, slotId: slotId,
            subjectId: subjectId, suggestion: 'اختر معلماً مؤهلاً آخر أو انقل إحدى الحصتين.',
          ));
        } else {
          teacherCells[teacherKey] = entry;
        }
        if (enforceQualifications && !qualified.contains('$teacherId:$subjectId')) {
          issues.add(ConflictIssue(
            type: 'تأهيل المعلم', severity: 'خطأ مانع',
            message: 'المعلم ${entry['teacher_name'] ?? teacherId} غير مسجل ضمن مؤهلي مادة ${entry['subject_name'] ?? subjectId}.',
            sectionId: sectionId, teacherId: teacherId, dayId: dayId, slotId: slotId,
            subjectId: subjectId, suggestion: 'أضف تأهيل المعلم لهذه المادة أو اختر معلماً مؤهلاً.',
          ));
        }
      } else {
        issues.add(ConflictIssue(
          type: 'حصة بلا معلم', severity: 'تحذير',
          message: 'حصة ${entry['subject_name'] ?? subjectId} في ${entry['section_name'] ?? sectionId} غير مسندة إلى معلم.',
          sectionId: sectionId, dayId: dayId, slotId: slotId, subjectId: subjectId,
          suggestion: 'أسند الحصة إلى معلم مؤهل قبل اعتماد الجدول.',
        ));
      }

      if (roomId != null) {
        final roomKey = '$roomId:$key';
        final priorRoom = roomCells[roomKey];
        if (priorRoom != null && _int(priorRoom['id']) != _int(entry['id'])) {
          issues.add(ConflictIssue(
            type: 'تعارض القاعة', severity: 'خطأ مانع',
            message: 'القاعة ${entry['room_name'] ?? roomId} مستخدمة في حصتين متزامنتين.',
            sectionId: sectionId, dayId: dayId, slotId: slotId,
            suggestion: 'اختر قاعة أخرى أو انقل إحدى الحصتين.',
          ));
        } else {
          roomCells[roomKey] = entry;
        }
      }

      final slot = slotById[slotId];
      if (slot != null && (slot['kind'] != 'lesson' || _int(slot['is_available']) == 0)) {
        issues.add(ConflictIssue(
          type: 'فترة غير متاحة', severity: 'خطأ مانع',
          message: 'الحصة مدرجة في ${slot['name'] ?? 'فترة غير متاحة'} وليست فترة تدريس متاحة.',
          sectionId: sectionId, teacherId: teacherId, dayId: dayId, slotId: slotId,
          subjectId: subjectId, suggestion: 'انقل الحصة إلى فترة دراسية متاحة.',
        ));
      }
    }

    // مقارنة الحصص الفعلية مع الحصص المطلوبة لكل شعبة ومادة.
    final actual = <String, int>{};
    for (final entry in entries) {
      final key = '${_int(entry['section_id'])}:${_int(entry['subject_id'])}';
      actual[key] = (actual[key] ?? 0) + 1;
    }
    for (final req in requirements) {
      final sectionId = _int(req['section_id']);
      final subjectId = _int(req['subject_id']);
      final required = _int(req['weekly_lessons']);
      final placed = actual['$sectionId:$subjectId'] ?? 0;
      final label = '${req['subject_name'] ?? 'المادة $subjectId'} لشعبة ${req['section_name'] ?? sectionId}';
      if (placed < required) {
        issues.add(ConflictIssue(
          type: 'نقص الحصص', severity: 'تحذير',
          message: '$label: المطلوب $required حصة أسبوعياً، والموزع $placed.',
          sectionId: sectionId, subjectId: subjectId,
          suggestion: 'أضف ${required - placed} حصة في فترات متاحة.',
        ));
      } else if (placed > required) {
        issues.add(ConflictIssue(
          type: 'حصص زائدة', severity: 'تحذير',
          message: '$label: المطلوب $required حصة أسبوعياً، والموزع $placed.',
          sectionId: sectionId, subjectId: subjectId,
          suggestion: 'احذف أو أعد إسناد ${placed - required} حصة زائدة.',
        ));
      }
    }

    // حدود النصاب الأسبوعي للمعلمين.
    final weeklyCounts = <int, int>{};
    final dailyCounts = <String, int>{};
    final teacherDaySlots = <String, List<int>>{};
    final subjectDailyCounts = <String, int>{};
    final requirementByKey = <String, Map<String, Object?>>{
      for (final r in requirements) '${_int(r['section_id'])}:${_int(r['subject_id'])}': r,
    };
    for (final entry in entries) {
      final teacherId = _nullableInt(entry['teacher_id']);
      if (teacherId == null) continue;
      final key = '$teacherId:${_int(entry['day_id'])}';
      dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
      weeklyCounts[teacherId] = (weeklyCounts[teacherId] ?? 0) + 1;
      final pos = slotById[_int(entry['slot_id'])]?['position'];
      if (pos is int) (teacherDaySlots[key] ??= <int>[]).add(pos);
    }
    for (final item in weeklyCounts.entries) {
      final teacher = teacherById[item.key];
      final limit = teacher == null ? 0 : _int(teacher['weekly_load']);
      if (limit > 0 && item.value > limit) {
        issues.add(ConflictIssue(
          type: 'تجاوز النصاب الأسبوعي', severity: 'تحذير',
          message: 'المعلم ${teacher?['name'] ?? item.key} لديه ${item.value} حصة، متجاوزاً النصاب المسجل ${limit}.',
          teacherId: item.key, suggestion: 'أعد توزيع بعض الحصص أو عدّل النصاب إذا كانت سياسة المدرسة تسمح.',
        ));
      }
    }
    for (final entry in entries) {
      final key = '${_int(entry['section_id'])}:${_int(entry['subject_id'])}:${_int(entry['day_id'])}';
      subjectDailyCounts[key] = (subjectDailyCounts[key] ?? 0) + 1;
    }
    for (final item in subjectDailyCounts.entries) {
      final parts = item.key.split(':').map(int.parse).toList();
      final req = requirementByKey['${parts[0]}:${parts[1]}'];
      if (req == null) continue;
      final maxDaily = _int(req['max_daily_lessons'], fallback: 2);
      final repeatAllowed = _int(req['allow_same_day']) == 1;
      final limit = repeatAllowed ? (maxDaily <= 0 ? 1 : maxDaily) : 1;
      if (item.value > limit) {
        issues.add(ConflictIssue(
          type: 'تكرار المادة يومياً', severity: 'تحذير',
          message: 'تكررت ${req['subject_name'] ?? 'المادة ${parts[1]}'} في الشعبة ${req['section_name'] ?? parts[0]} ${item.value} مرات في اليوم نفسه (الحد $limit).',
          sectionId: parts[0], subjectId: parts[1], dayId: parts[2],
          suggestion: 'وزّع حصص المادة على أيام مختلفة أو راجع حد التكرار اليومي.',
        ));
      }
    }
    for (final item in teacherDaySlots.entries) {
      final parts = item.key.split(':');
      final teacherId = int.parse(parts[0]);
      final dayId = int.parse(parts[1]);
      final teacher = teacherById[teacherId];
      final maxConsecutive = teacher == null ? 0 : _int(teacher['max_consecutive_lessons']);
      if (maxConsecutive > 0) {
        final positions = [...item.value]..sort();
        var run = positions.isEmpty ? 0 : 1;
        var longest = run;
        for (var i = 1; i < positions.length; i++) {
          run = positions[i] == positions[i - 1] + 1 ? run + 1 : 1;
          if (run > longest) longest = run;
        }
        if (longest > maxConsecutive) {
          issues.add(ConflictIssue(
            type: 'حصص متتالية زائدة', severity: 'تحذير',
            message: 'لدى المعلم ${teacher?['name'] ?? teacherId} ${longest} حصص متتالية في اليوم رقم $dayId، والحد $maxConsecutive.',
            teacherId: teacherId, dayId: dayId, suggestion: 'أدخل فترة فاصلة أو أعد توزيع حصة على يوم آخر.',
          ));
        }
      }
    }
    for (final item in dailyCounts.entries) {
      final parts = item.key.split(':');
      final teacherId = int.parse(parts[0]);
      final dayId = int.parse(parts[1]);
      final teacher = teacherById[teacherId];
      final limit = teacher == null ? 0 : _int(teacher['max_daily_lessons']);
      if (limit > 0 && item.value > limit) {
        issues.add(ConflictIssue(
          type: 'تجاوز الحد اليومي', severity: 'تحذير',
          message: 'تجاوز المعلم ${teacher?['name'] ?? teacherId} الحد اليومي في اليوم رقم $dayId (${item.value} من $limit).',
          teacherId: teacherId, dayId: dayId,
          suggestion: 'انقل بعض حصص المعلم إلى يوم آخر.',
        ));
      }
    }
    return issues;
  }

  static int? _minutes(Object? value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }
  static int _int(Object? value, {int fallback = 0}) => value is int ? value : int.tryParse('$value') ?? fallback;
  static int? _nullableInt(Object? value) => value == null ? null : _int(value);
}
