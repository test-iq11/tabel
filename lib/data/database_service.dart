import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// مصدر البيانات المحلي الوحيد للتطبيق. جميع البيانات المدرسية تحفظ في SQLite.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _database;

  static const int schemaVersion = 1;
  static const List<String> backupTables = [
    'academic_years', 'school_settings', 'stages', 'grades', 'sections',
    'subjects', 'teachers', 'teacher_subjects', 'school_days', 'time_slots',
    'teacher_availability', 'section_subject_requirements', 'rooms',
    'timetable_versions', 'timetable_entries', 'audit_log',
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    final base = await getDatabasesPath();
    _database = await openDatabase(
      p.join(base, 'iraqi_school_timetable.db'),
      version: schemaVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: (db, oldVersion, newVersion) async {
        // ترحيلات المخطط المستقبلية تضاف هنا دون حذف البيانات الحالية.
      },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db, int version) async {
    final statements = <String>[
      '''CREATE TABLE academic_years (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''',
      '''CREATE TABLE school_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        school_name TEXT NOT NULL DEFAULT 'مدرستي',
        directorate TEXT NOT NULL DEFAULT '',
        stage TEXT NOT NULL DEFAULT 'الابتدائية',
        default_lesson_minutes INTEGER NOT NULL DEFAULT 45,
        allow_unqualified_teacher INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE stages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        position INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage_id INTEGER NOT NULL REFERENCES stages(id) ON DELETE RESTRICT,
        name TEXT NOT NULL,
        max_daily_lessons INTEGER NOT NULL DEFAULT 7,
        position INTEGER NOT NULL DEFAULT 0,
        UNIQUE(stage_id, name)
      )''',
      '''CREATE TABLE sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_id INTEGER NOT NULL REFERENCES grades(id) ON DELETE RESTRICT,
        name TEXT NOT NULL,
        max_daily_lessons INTEGER NOT NULL DEFAULT 7,
        UNIQUE(grade_id, name)
      )''',
      '''CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        code TEXT NOT NULL DEFAULT '',
        color INTEGER NOT NULL DEFAULT 4280391411,
        max_daily_lessons INTEGER NOT NULL DEFAULT 2,
        allow_same_day INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL DEFAULT '',
        weekly_load INTEGER NOT NULL DEFAULT 24,
        max_daily_lessons INTEGER NOT NULL DEFAULT 6,
        max_consecutive_lessons INTEGER NOT NULL DEFAULT 4,
        notes TEXT NOT NULL DEFAULT ''
      )''',
      '''CREATE TABLE teacher_subjects (
        teacher_id INTEGER NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
        subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
        PRIMARY KEY(teacher_id, subject_id)
      )''',
      '''CREATE TABLE school_days (
        id INTEGER PRIMARY KEY,
        position INTEGER NOT NULL,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1
      )''',
      '''CREATE TABLE time_slots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'lesson',
        position INTEGER NOT NULL DEFAULT 0,
        is_available INTEGER NOT NULL DEFAULT 1
      )''',
      '''CREATE TABLE teacher_availability (
        teacher_id INTEGER NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
        day_id INTEGER NOT NULL REFERENCES school_days(id) ON DELETE CASCADE,
        slot_id INTEGER NOT NULL REFERENCES time_slots(id) ON DELETE CASCADE,
        is_available INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY(teacher_id, day_id, slot_id)
      )''',
      '''CREATE TABLE section_subject_requirements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        section_id INTEGER NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
        subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
        weekly_lessons INTEGER NOT NULL DEFAULT 0,
        max_daily_lessons INTEGER NOT NULL DEFAULT 2,
        allow_same_day INTEGER NOT NULL DEFAULT 0,
        UNIQUE(section_id, subject_id)
      )''',
      '''CREATE TABLE rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        kind TEXT NOT NULL DEFAULT 'قاعة'
      )''',
      '''CREATE TABLE timetable_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        academic_year_id INTEGER NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
        name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'مسودة',
        notes TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        approved_at TEXT
      )''',
      '''CREATE TABLE timetable_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version_id INTEGER NOT NULL REFERENCES timetable_versions(id) ON DELETE CASCADE,
        section_id INTEGER NOT NULL REFERENCES sections(id) ON DELETE RESTRICT,
        subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
        teacher_id INTEGER REFERENCES teachers(id) ON DELETE SET NULL,
        room_id INTEGER REFERENCES rooms(id) ON DELETE SET NULL,
        day_id INTEGER NOT NULL REFERENCES school_days(id) ON DELETE RESTRICT,
        slot_id INTEGER NOT NULL REFERENCES time_slots(id) ON DELETE RESTRICT,
        created_at TEXT NOT NULL,
        UNIQUE(version_id, section_id, day_id, slot_id)
      )''',
      '''CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        entity_id INTEGER,
        details TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )''',
      'CREATE INDEX idx_entries_version_day_slot ON timetable_entries(version_id, day_id, slot_id)',
      'CREATE INDEX idx_entries_section ON timetable_entries(section_id, version_id)',
      'CREATE INDEX idx_entries_teacher ON timetable_entries(teacher_id, version_id)',
      'CREATE INDEX idx_requirements_section ON section_subject_requirements(section_id)',
    ];
    for (final sql in statements) {
      await db.execute(sql);
    }
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('school_settings', {
      'id': 1,
      'school_name': 'مدرستي',
      'directorate': '',
      'stage': 'الابتدائية',
      'default_lesson_minutes': 45,
      'allow_unqualified_teacher': 0,
    });
    final yearId = await db.insert('academic_years', {
      'name': '${DateTime.now().year}-${DateTime.now().year + 1}',
      'is_active': 1,
      'created_at': now,
    });
    final stageId = await db.insert('stages', {'name': 'الابتدائية', 'position': 0});
    const gradeNames = [
      'الأول الابتدائي', 'الثاني الابتدائي', 'الثالث الابتدائي',
      'الرابع الابتدائي', 'الخامس الابتدائي', 'السادس الابتدائي',
    ];
    for (var i = 0; i < gradeNames.length; i++) {
      await db.insert('grades', {
        'stage_id': stageId, 'name': gradeNames[i], 'position': i, 'max_daily_lessons': 7,
      });
    }
    const days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    for (var i = 0; i < days.length; i++) {
      await db.insert('school_days', {'id': i + 1, 'position': i, 'name': days[i], 'is_active': 1});
    }
    const slots = [
      ['الحصة الأولى', '08:00', '08:45', 'lesson'],
      ['الحصة الثانية', '08:50', '09:30', 'lesson'],
      ['الحصة الثالثة', '09:35', '10:10', 'lesson'],
      ['الحصة الرابعة', '10:20', '11:00', 'lesson'],
      ['الحصة الخامسة', '11:05', '11:45', 'lesson'],
    ];
    for (var i = 0; i < slots.length; i++) {
      await db.insert('time_slots', {
        'name': slots[i][0], 'start_time': slots[i][1], 'end_time': slots[i][2],
        'kind': slots[i][3], 'position': i, 'is_available': 1,
      });
    }
    const subjects = [
      'التربية الإسلامية', 'اللغة العربية', 'اللغة الإنجليزية', 'الرياضيات',
      'العلوم', 'الاجتماعيات', 'التربية الفنية', 'التربية الرياضية', 'الحاسوب',
    ];
    for (var i = 0; i < subjects.length; i++) {
      await db.insert('subjects', {
        'name': subjects[i], 'code': '', 'color': 4280391411,
        'max_daily_lessons': 2, 'allow_same_day': 0,
      });
    }
    final versionId = await db.insert('timetable_versions', {
      'academic_year_id': yearId,
      'name': 'الجدول الأولي',
      'status': 'مسودة',
      'notes': 'نسخة أولية فارغة أنشئت عند إعداد التطبيق',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('audit_log', {
      'action': 'إنشاء', 'entity': 'timetable_version', 'entity_id': versionId,
      'details': 'إنشاء النسخة الأولية', 'created_at': now,
    });
  }

  Future<List<Map<String, Object?>>> rows(String table, {String? orderBy}) async {
    const allowed = {
      'academic_years', 'school_settings', 'stages', 'grades', 'sections', 'subjects',
      'teachers', 'teacher_subjects', 'school_days', 'time_slots', 'teacher_availability',
      'section_subject_requirements', 'rooms', 'timetable_versions', 'timetable_entries', 'audit_log',
    };
    if (!allowed.contains(table)) throw ArgumentError('اسم جدول غير مسموح: $table');
    return (await database).query(table, orderBy: orderBy);
  }

  Future<List<Map<String, Object?>>> sectionsDetailed() async => (await database).rawQuery('''
    SELECT s.id, s.name AS section_name, s.grade_id, s.max_daily_lessons,
           g.name AS grade_name, g.stage_id, st.name AS stage_name,
           (SELECT COUNT(*) FROM section_subject_requirements r WHERE r.section_id=s.id) AS requirements_count,
           (SELECT COALESCE(SUM(weekly_lessons),0) FROM section_subject_requirements r WHERE r.section_id=s.id) AS required_lessons
    FROM sections s JOIN grades g ON g.id=s.grade_id JOIN stages st ON st.id=g.stage_id
    ORDER BY st.position, g.position, g.id, s.name
  ''');

  Future<List<Map<String, Object?>>> gradesDetailed() async => (await database).rawQuery('''
    SELECT g.*, st.name AS stage_name FROM grades g JOIN stages st ON st.id=g.stage_id
    ORDER BY st.position, g.position, g.name
  ''');

  Future<List<Map<String, Object?>>> entriesDetailed({int? versionId, int? sectionId}) async {
    final yearVersion = versionId ?? await activeVersionId(await activeYearId());
    if (yearVersion == null) return [];
    final where = <String>[];
    final args = <Object?>[yearVersion];
    if (sectionId != null) { where.add('e.section_id = ?'); args.add(sectionId); }
    return (await database).rawQuery('''
      SELECT e.*, s.name AS subject_name, t.name AS teacher_name, sec.name AS section_name,
             g.name AS grade_name, d.name AS day_name, d.position AS day_position,
             ts.name AS slot_name, ts.start_time, ts.end_time, ts.position AS slot_position,
             r.name AS room_name, v.name AS version_name, v.status AS version_status
      FROM timetable_entries e
      JOIN subjects s ON s.id=e.subject_id
      LEFT JOIN teachers t ON t.id=e.teacher_id
      JOIN sections sec ON sec.id=e.section_id
      JOIN grades g ON g.id=sec.grade_id
      JOIN school_days d ON d.id=e.day_id
      JOIN time_slots ts ON ts.id=e.slot_id
      LEFT JOIN rooms r ON r.id=e.room_id
      JOIN timetable_versions v ON v.id=e.version_id
      WHERE e.version_id = ? ${where.isEmpty ? '' : 'AND ${where.join(' AND ')}'}
      ORDER BY d.position, ts.position, g.position, sec.name
    ''', args);
  }

  Future<List<Map<String, Object?>>> requirementsDetailed({int? sectionId}) async {
    final args = <Object?>[];
    var clause = '';
    if (sectionId != null) { clause = 'WHERE r.section_id=?'; args.add(sectionId); }
    return (await database).rawQuery('''
      SELECT r.*, sec.name AS section_name, g.name AS grade_name, sub.name AS subject_name
      FROM section_subject_requirements r
      JOIN sections sec ON sec.id=r.section_id JOIN grades g ON g.id=sec.grade_id
      JOIN subjects sub ON sub.id=r.subject_id $clause
      ORDER BY g.position, sec.name, sub.name
    ''', args);
  }

  Future<int?> activeYearId() async {
    final result = await (await database).query('academic_years', where: 'is_active=1', limit: 1);
    if (result.isEmpty) return null;
    return result.first['id'] as int;
  }

  Future<Map<String, Object?>?> activeYear() async {
    final result = await (await database).query('academic_years', where: 'is_active=1', limit: 1);
    return result.isEmpty ? null : result.first;
  }

  Future<void> setActiveYear(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('academic_years', {'is_active': 0});
      await txn.update('academic_years', {'is_active': 1}, where: 'id=?', whereArgs: [id]);
      final existing = await txn.query('timetable_versions', where: 'academic_year_id=? AND is_active=1', whereArgs: [id], limit: 1);
      if (existing.isEmpty) {
        final now = DateTime.now().toIso8601String();
        await txn.insert('timetable_versions', {
          'academic_year_id': id, 'name': 'الجدول الأولي', 'status': 'مسودة',
          'notes': '', 'is_active': 1, 'created_at': now, 'updated_at': now,
        });
      }
    });
  }

  Future<int?> activeVersionId(int? yearId) async {
    if (yearId == null) return null;
    final result = await (await database).query('timetable_versions',
        columns: ['id'], where: 'academic_year_id=? AND is_active=1', whereArgs: [yearId], limit: 1);
    return result.isEmpty ? null : result.first['id'] as int;
  }

  Future<int> add(String table, Map<String, Object?> values) async {
    final db = await database;
    final id = await db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.abort);
    await log('إضافة', table, id, 'إضافة سجل جديد');
    return id;
  }

  Future<int> edit(String table, int id, Map<String, Object?> values) async {
    final count = await (await database).update(table, values, where: 'id=?', whereArgs: [id]);
    if (count > 0) await log('تعديل', table, id, jsonEncode(values));
    return count;
  }

  Future<int> remove(String table, int id) async {
    final count = await (await database).delete(table, where: 'id=?', whereArgs: [id]);
    if (count > 0) await log('حذف', table, id, 'حذف سجل');
    return count;
  }

  Future<void> log(String action, String entity, int? id, String details) async {
    await (await database).insert('audit_log', {
      'action': action, 'entity': entity, 'entity_id': id,
      'details': details, 'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, Object?>> getSettings() async {
    final result = await (await database).query('school_settings', where: 'id=1', limit: 1);
    return result.isEmpty ? {'school_name': 'مدرستي'} : result.first;
  }

  Future<void> saveSettings(Map<String, Object?> values) async {
    await (await database).update('school_settings', values, where: 'id=1');
    await log('تعديل', 'school_settings', 1, jsonEncode(values));
  }

  Future<List<int>> qualifiedTeacherIds(int subjectId) async {
    final data = await (await database).query('teacher_subjects',
        columns: ['teacher_id'], where: 'subject_id=?', whereArgs: [subjectId]);
    return data.map((e) => e['teacher_id'] as int).toList();
  }

  /// ينسخ النسخة المعتمدة إلى نسخة عمل قبل أول تعديل، حتى تبقى المعتمدة ثابتة.
  Future<int?> ensureEditableActiveVersion(int yearId) async {
    final db = await database;
    return db.transaction((txn) async {
      final versions = await txn.query('timetable_versions',
          where: 'academic_year_id=? AND is_active=1', whereArgs: [yearId], limit: 1);
      if (versions.isEmpty) return null;
      final active = versions.first;
      if (active['status'] != 'معتمد') return active['id'] as int;
      final now = DateTime.now().toIso8601String();
      final newId = await txn.insert('timetable_versions', {
        'academic_year_id': yearId,
        'name': 'تعديلات على ${active['name']}',
        'status': 'قيد التعديل',
        'notes': 'نسخة عمل مشتقة تلقائياً من النسخة المعتمدة رقم ${active['id']}.',
        'is_active': 0, 'created_at': now, 'updated_at': now,
      });
      final oldEntries = await txn.query('timetable_entries',
          where: 'version_id=?', whereArgs: [active['id']]);
      for (final old in oldEntries) {
        final row = Map<String, Object?>.from(old);
        row.remove('id');
        row.remove('version_id');
        row.remove('created_at');
        await txn.insert('timetable_entries', {...row, 'version_id': newId, 'created_at': now});
      }
      await txn.update('timetable_versions', {'is_active': 0}, where: 'id=?', whereArgs: [active['id']]);
      await txn.update('timetable_versions', {'is_active': 1}, where: 'id=?', whereArgs: [newId]);
      await txn.insert('audit_log', {
        'action': 'إنشاء نسخة عمل', 'entity': 'timetable_versions', 'entity_id': newId,
        'details': 'نسخ النسخة المعتمدة رقم ${active['id']} قبل التعديل', 'created_at': now,
      });
      return newId;
    });
  }

  Future<void> saveEntry(Map<String, Object?> values, {int? entryId}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (entryId == null) {
        await txn.insert('timetable_entries', values);
      } else {
        await txn.update('timetable_entries', values, where: 'id=?', whereArgs: [entryId]);
      }
      await txn.update('timetable_versions', {
        'status': 'قيد التعديل', 'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id=?', whereArgs: [values['version_id']]);
    });
    await log(entryId == null ? 'إضافة حصة' : 'تعديل حصة', 'timetable_entries', entryId, jsonEncode(values));
  }

  /// يحفظ نتيجة الجدولة كنسخة جديدة ولا يمس النسخة القديمة.
  Future<int> saveAsNewVersion({required int yearId, required String name,
      required List<Map<String, Object?>> entries, String notes = 'نتيجة الجدولة التلقائية'}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final versionId = await txn.insert('timetable_versions', {
        'academic_year_id': yearId, 'name': name, 'status': 'مسودة', 'notes': notes,
        'is_active': 0, 'created_at': now, 'updated_at': now,
      });
      for (final entry in entries) {
        await txn.insert('timetable_entries', {...entry, 'version_id': versionId, 'created_at': now});
      }
      await txn.update('timetable_versions', {'is_active': 0},
          where: 'academic_year_id=?', whereArgs: [yearId]);
      await txn.update('timetable_versions', {'is_active': 1}, where: 'id=?', whereArgs: [versionId]);
      await txn.insert('audit_log', {
        'action': 'إنشاء نسخة', 'entity': 'timetable_versions', 'entity_id': versionId,
        'details': 'حفظ $name بعد إنشاء ${entries.length} حصة', 'created_at': now,
      });
      return versionId;
    });
  }

  Future<Map<String, Object?>> summary() async {
    final db = await database;
    final yearId = await activeYearId();
    final versionId = await activeVersionId(yearId);
    final result = <String, Object?>{};
    for (final item in [
      ['grades', 'عدد الصفوف'], ['sections', 'عدد الشعب'],
      ['subjects', 'عدد المواد'], ['teachers', 'عدد المعلمين'],
    ]) {
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${item[0]}')) ?? 0;
      result[item[1] as String] = count;
    }
    final required = Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(SUM(weekly_lessons),0) FROM section_subject_requirements')) ?? 0;
    final distributed = versionId == null ? 0 : (Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM timetable_entries WHERE version_id=?', [versionId])) ?? 0);
    result['الحصص المطلوبة'] = required;
    result['الحصص الموزعة'] = distributed;
    result['الحصص المتبقية'] = (required - distributed) < 0 ? 0 : required - distributed;
    result['نسبة الاكتمال'] = required == 0 ? 0.0 : (distributed / required).clamp(0.0, 1.0);
    result['العام الدراسي'] = (await activeYear())?['name'] ?? 'غير محدد';
    result['version_id'] = versionId;
    return result;
  }

  Future<Map<String, Object?>> exportAll() async {
    final db = await database;
    final data = <String, Object?>{
      'format': 'iraqi_school_timetable_backup',
      'schema_version': schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': <String, Object?>{},
    };
    final tables = data['tables'] as Map<String, Object?>;
    for (final table in backupTables) {
      tables[table] = await db.query(table);
    }
    return data;
  }

  Future<void> importAll(Map<String, Object?> backup) async {
    if (backup['format'] != 'iraqi_school_timetable_backup' || backup['schema_version'] != schemaVersion || backup['tables'] is! Map) {
      throw const FormatException('ملف النسخة الاحتياطية غير معروف أو غير متوافق مع إصدار قاعدة البيانات.');
    }
    final source = (backup['tables'] as Map).cast<String, dynamic>();
    for (final table in backupTables) {
      if (source[table] is! List) throw FormatException('الجدول $table مفقود من النسخة الاحتياطية.');
    }
    final db = await database;
    // جميع خطوات الاستعادة داخل معاملة واحدة: إما استعادة كاملة أو تراجع كامل.
    await db.transaction((txn) async {
      for (final table in backupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in backupTables) {
        final records = (source[table] as List).cast<Map>();
        for (final record in records) {
          await txn.insert(table, record.cast<String, Object?>(), conflictAlgorithm: ConflictAlgorithm.abort);
        }
      }
    });
  }
}

