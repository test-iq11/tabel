import 'dart:convert';

class SchoolSettings {
  final int? id;
  final String schoolName;
  final String directorateName;
  final String stageName;
  final String academicYear;
  final int workingDaysCount;
  final int dailyPeriodsCount;
  final int defaultPeriodDuration;
  final String notes;

  SchoolSettings({
    this.id,
    required this.schoolName,
    required this.directorateName,
    required this.stageName,
    required this.academicYear,
    this.workingDaysCount = 5,
    this.dailyPeriodsCount = 5,
    this.defaultPeriodDuration = 45,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_name': schoolName,
      'directorate_name': directorateName,
      'stage_name': stageName,
      'academic_year': academicYear,
      'working_days_count': workingDaysCount,
      'daily_periods_count': dailyPeriodsCount,
      'default_period_duration': defaultPeriodDuration,
      'notes': notes,
    };
  }

  factory SchoolSettings.fromMap(Map<String, dynamic> map) {
    return SchoolSettings(
      id: map['id'],
      schoolName: map['school_name'] ?? '',
      directorateName: map['directorate_name'] ?? '',
      stageName: map['stage_name'] ?? '',
      academicYear: map['academic_year'] ?? '',
      workingDaysCount: map['working_days_count'] ?? 5,
      dailyPeriodsCount: map['daily_periods_count'] ?? 5,
      defaultPeriodDuration: map['default_period_duration'] ?? 45,
      notes: map['notes'] ?? '',
    );
  }
}

class Grade {
  final int? id;
  final String name;
  final int level;

  Grade({this.id, required this.name, required this.level});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'level': level};
  factory Grade.fromMap(Map<String, dynamic> map) => Grade(id: map['id'], name: map['name'], level: map['level']);
}

class Section {
  final int? id;
  final int gradeId;
  final String name;
  final int requiredWeeklyPeriods;

  Section({this.id, required this.gradeId, required this.name, this.requiredWeeklyPeriods = 25});

  Map<String, dynamic> toMap() => {
    'id': id,
    'grade_id': gradeId,
    'name': name,
    'required_weekly_periods': requiredWeeklyPeriods,
  };

  factory Section.fromMap(Map<String, dynamic> map) => Section(
    id: map['id'],
    gradeId: map['grade_id'],
    name: map['name'],
    requiredWeeklyPeriods: map['required_weekly_periods'] ?? 25,
  );
}

class Subject {
  final int? id;
  final String name;
  final String code;
  final String colorHex;
  final int gradeId;
  final int weeklyPeriodsCount;
  final int maxDailyPeriods;

  Subject({
    this.id,
    required this.name,
    this.code = '',
    this.colorHex = '#1976D2',
    required this.gradeId,
    required this.weeklyPeriodsCount,
    this.maxDailyPeriods = 2,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'color_hex': colorHex,
    'grade_id': gradeId,
    'weekly_periods_count': weeklyPeriodsCount,
    'max_daily_periods': maxDailyPeriods,
  };

  factory Subject.fromMap(Map<String, dynamic> map) => Subject(
    id: map['id'],
    name: map['name'],
    code: map['code'] ?? '',
    colorHex: map['color_hex'] ?? '#1976D2',
    gradeId: map['grade_id'],
    weeklyPeriodsCount: map['weekly_periods_count'],
    maxDailyPeriods: map['max_daily_periods'] ?? 2,
  );
}

class Teacher {
  final int? id;
  final String fullName;
  final String code;
  final int targetWeeklyQuota;
  final int maxDailyQuota;
  final int maxConsecutivePeriods;

  Teacher({
    this.id,
    required this.fullName,
    this.code = '',
    this.targetWeeklyQuota = 24,
    this.maxDailyQuota = 5,
    this.maxConsecutivePeriods = 3,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': fullName,
    'code': code,
    'target_weekly_quota': targetWeeklyQuota,
    'max_daily_quota': maxDailyQuota,
    'max_consecutive_periods': maxConsecutivePeriods,
  };

  factory Teacher.fromMap(Map<String, dynamic> map) => Teacher(
    id: map['id'],
    fullName: map['full_name'],
    code: map['code'] ?? '',
    targetWeeklyQuota: map['target_weekly_quota'] ?? 24,
    maxDailyQuota: map['max_daily_quota'] ?? 5,
    maxConsecutivePeriods: map['max_consecutive_periods'] ?? 3,
  );
}

class TimeSlot {
  final int? id;
  final String name;
  final String startTime;
  final String endTime;
  final String type; // 'lesson', 'break', 'activity', 'unavailable'
  final int periodOrder;

  TimeSlot({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.type = 'lesson',
    required this.periodOrder,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'start_time': startTime,
    'end_time': endTime,
    'type': type,
    'period_order': periodOrder,
  };

  factory TimeSlot.fromMap(Map<String, dynamic> map) => TimeSlot(
    id: map['id'],
    name: map['name'],
    startTime: map['start_time'],
    endTime: map['end_time'],
    type: map['type'] ?? 'lesson',
    periodOrder: map['period_order'],
  );
}

class TimetableVersion {
  final int? id;
  final String versionName;
  final String academicYear;
  final String status; // 'draft', 'review', 'approved'
  final String createdAt;
  final String notes;

  TimetableVersion({
    this.id,
    required this.versionName,
    required this.academicYear,
    this.status = 'draft',
    required this.createdAt,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'version_name': versionName,
    'academic_year': academicYear,
    'status': status,
    'created_at': createdAt,
    'notes': notes,
  };

  factory TimetableVersion.fromMap(Map<String, dynamic> map) => TimetableVersion(
    id: map['id'],
    versionName: map['version_name'],
    academicYear: map['academic_year'],
    status: map['status'] ?? 'draft',
    createdAt: map['created_at'],
    notes: map['notes'] ?? '',
  );
}

class TimetableEntry {
  final int? id;
  final int versionId;
  final int sectionId;
  final int subjectId;
  final int teacherId;
  final int timeSlotId;
  final String dayOfWeek; // 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'

  TimetableEntry({
    this.id,
    required this.versionId,
    required this.sectionId,
    required this.subjectId,
    required this.teacherId,
    required this.timeSlotId,
    required this.dayOfWeek,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'version_id': versionId,
    'section_id': sectionId,
    'subject_id': subjectId,
    'teacher_id': teacherId,
    'time_slot_id': timeSlotId,
    'day_of_week': dayOfWeek,
  };

  factory TimetableEntry.fromMap(Map<String, dynamic> map) => TimetableEntry(
    id: map['id'],
    versionId: map['version_id'],
    sectionId: map['section_id'],
    subjectId: map['subject_id'],
    teacherId: map['teacher_id'],
    timeSlotId: map['time_slot_id'],
    dayOfWeek: map['day_of_week'],
  );
}

class ConflictResult {
  final String type; // 'error', 'warning', 'info'
  final String title;
  final String description;
  final String solutionSuggestion;
  final int? sectionId;
  final int? teacherId;
  final int? timeSlotId;

  ConflictResult({
    required this.type,
    required this.title,
    required this.description,
    required this.solutionSuggestion,
    this.sectionId,
    this.teacherId,
    this.timeSlotId,
  });
}
