import '../models/app_models.dart';
import '../services/database_service.dart';

class ConflictDetectionService {
  final DatabaseService _dbService = DatabaseService();

  Future<List<ConflictResult>> checkAllConflicts(int versionId) async {
    List<ConflictResult> conflicts = [];
    final db = await _dbService.database;

    List<Map<String, dynamic>> entries = await db.query(
      'timetable_entries',
      where: 'version_id = ?',
      whereArgs: [versionId],
    );

    // 1. Teacher Conflicts: Same teacher in multiple sections at same day & slot
    Map<String, List<Map<String, dynamic>>> teacherSlotMap = {};
    for (var entry in entries) {
      String key = "\${entry['teacher_id']}_\${entry['day_of_week']}_\${entry['time_slot_id']}";
      teacherSlotMap.putIfAbsent(key, () => []).add(entry);
    }

    for (var entryList in teacherSlotMap.values) {
      if (entryList.length > 1) {
        var tId = entryList.first['teacher_id'];
        var teacherList = await db.query('teachers', where: 'id = ?', whereArgs: [tId]);
        String teacherName = teacherList.isNotEmpty ? teacherList.first['full_name'] : 'معلم';
        
        conflicts.add(ConflictResult(
          type: 'error',
          title: 'تعارض معلم شديد',
          description: 'المعلم (\$teacherName) مسند لأكثر من شعبة في نفس الوقت والدفعة الزمنية!',
          solutionSuggestion: 'قم بتغيير موعد إحدى الحصص أو إسناد معلم آخر.',
          teacherId: tId,
          timeSlotId: entryList.first['time_slot_id'],
        ));
      }
    }

    // 2. Section Conflicts: Same section having multiple lessons at same day & slot
    Map<String, List<Map<String, dynamic>>> sectionSlotMap = {};
    for (var entry in entries) {
      String key = "\${entry['section_id']}_\${entry['day_of_week']}_\${entry['time_slot_id']}";
      sectionSlotMap.putIfAbsent(key, () => []).add(entry);
    }

    for (var entryList in sectionSlotMap.values) {
      if (entryList.length > 1) {
        var sId = entryList.first['section_id'];
        conflicts.add(ConflictResult(
          type: 'error',
          title: 'تعارض شعبة',
          description: 'الشعبة مسند لها أكثر من مادة في نفس الوقت!',
          solutionSuggestion: 'حذف أو تغيير موعد إحدى المواد الحالية.',
          sectionId: sId,
          timeSlotId: entryList.first['time_slot_id'],
        ));
      }
    }

    return conflicts;
  }
}

class AutoSchedulerService {
  final DatabaseService _dbService = DatabaseService();

  Future<bool> generateTimetable(int versionId) async {
    final db = await _dbService.database;

    // Fetch data
    List<Map<String, dynamic>> sections = await db.query('sections');
    List<Map<String, dynamic>> teachers = await db.query('teachers');
    List<Map<String, dynamic>> slots = await db.query('time_slots', where: "type = 'lesson'", orderBy: 'period_order ASC');
    
    List<String> days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

    if (sections.isEmpty || teachers.isEmpty || slots.isEmpty) {
      return false;
    }

    // Clear old entries for this version
    await db.delete('timetable_entries', where: 'version_id = ?', whereArgs: [versionId]);

    int teacherIdx = 0;

    for (var sec in sections) {
      List<Map<String, dynamic>> subjects = await db.query('subjects', where: 'grade_id = ?', whereArgs: [sec['grade_id']]);
      if (subjects.isEmpty) continue;

      int subIdx = 0;
      for (String day in days) {
        for (var slot in slots) {
          var currentSub = subjects[subIdx % subjects.length];
          var currentTeacher = teachers[teacherIdx % teachers.length];

          await db.insert('timetable_entries', {
            'version_id': versionId,
            'section_id': sec['id'],
            'subject_id': currentSub['id'],
            'teacher_id': currentTeacher['id'],
            'time_slot_id': slot['id'],
            'day_of_week': day,
          });

          subIdx++;
          teacherIdx++;
        }
      }
    }

    return true;
  }
}
