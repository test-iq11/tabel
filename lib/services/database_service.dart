import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'iraqi_school_timetable.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE school_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_name TEXT NOT NULL,
        directorate_name TEXT NOT NULL,
        stage_name TEXT NOT NULL,
        academic_year TEXT NOT NULL,
        working_days_count INTEGER NOT NULL DEFAULT 5,
        daily_periods_count INTEGER NOT NULL DEFAULT 5,
        default_period_duration INTEGER NOT NULL DEFAULT 45,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        required_weekly_periods INTEGER NOT NULL DEFAULT 25,
        FOREIGN KEY (grade_id) REFERENCES grades (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT,
        color_hex TEXT DEFAULT '#1976D2',
        grade_id INTEGER NOT NULL,
        weekly_periods_count INTEGER NOT NULL,
        max_daily_periods INTEGER NOT NULL DEFAULT 2,
        FOREIGN KEY (grade_id) REFERENCES grades (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        code TEXT,
        target_weekly_quota INTEGER NOT NULL DEFAULT 24,
        max_daily_quota INTEGER NOT NULL DEFAULT 5,
        max_consecutive_periods INTEGER NOT NULL DEFAULT 3
      )
    ''');

    await db.execute('''
      CREATE TABLE teacher_subjects (
        teacher_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        PRIMARY KEY (teacher_id, subject_id),
        FOREIGN KEY (teacher_id) REFERENCES teachers (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE time_slots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'lesson',
        period_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE timetable_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version_name TEXT NOT NULL,
        academic_year TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE timetable_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version_id INTEGER NOT NULL,
        section_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        teacher_id INTEGER NOT NULL,
        time_slot_id INTEGER NOT NULL,
        day_of_week TEXT NOT NULL,
        FOREIGN KEY (version_id) REFERENCES timetable_versions (id) ON DELETE CASCADE,
        FOREIGN KEY (section_id) REFERENCES sections (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE,
        FOREIGN KEY (teacher_id) REFERENCES teachers (id) ON DELETE CASCADE,
        FOREIGN KEY (time_slot_id) REFERENCES time_slots (id) ON DELETE CASCADE
      )
    ''');

    await db.insert('school_settings', {
      'school_name': 'مدرسة الأمل الابتدائية النموذجية',
      'directorate_name': 'مديرية تربية ذي قار',
      'stage_name': 'الابتدائية',
      'academic_year': '2026-2027',
      'working_days_count': 5,
      'daily_periods_count': 5,
      'default_period_duration': 45,
      'notes': 'جدول افتراضي معتمد للمدرسة',
    });

    List<Map<String, dynamic>> defaultSlots = [
      {'name': 'الحصة الأولى', 'start_time': '08:00', 'end_time': '08:45', 'type': 'lesson', 'period_order': 1},
      {'name': 'الحصة الثانية', 'start_time': '08:50', 'end_time': '09:30', 'type': 'lesson', 'period_order': 2},
      {'name': 'الحصة الثالثة', 'start_time': '09:35', 'end_time': '10:10', 'type': 'lesson', 'period_order': 3},
      {'name': 'الحصة الرابعة', 'start_time': '10:20', 'end_time': '11:00', 'type': 'lesson', 'period_order': 4},
      {'name': 'الحصة الخامسة', 'start_time': '11:05', 'end_time': '11:45', 'type': 'lesson', 'period_order': 5},
    ];

    for (var slot in defaultSlots) {
      await db.insert('time_slots', slot);
    }

    List<String> gradeNames = ['الأول الابتدائي', 'الثاني الابتدائي', 'الثالث الابتدائي', 'الرابع الابتدائي', 'الخامس الابتدائي', 'السادس الابتدائي'];
    for (int i = 0; i < gradeNames.length; i++) {
      int gradeId = await db.insert('grades', {'name': gradeNames[i], 'level': i + 1});
      
      await db.insert('sections', {'grade_id': gradeId, 'name': 'أ', 'required_weekly_periods': 25});
      await db.insert('sections', {'grade_id': gradeId, 'name': 'ب', 'required_weekly_periods': 25});

      List<Map<String, dynamic>> subjects = [
        {'name': 'التربية الإسلامية', 'code': 'إسلامية', 'color_hex': '#4CAF50', 'weekly_periods_count': 4},
        {'name': 'اللغة العربية', 'code': 'عربي', 'color_hex': '#1976D2', 'weekly_periods_count': 6},
        {'name': 'اللغة الإنجليزية', 'code': 'إنكليزي', 'color_hex': '#FF9800', 'weekly_periods_count': 4},
        {'name': 'الرياضيات', 'code': 'رياضيات', 'color_hex': '#9C27B0', 'weekly_periods_count': 5},
        {'name': 'العلوم', 'code': 'علوم', 'color_hex': '#009688', 'weekly_periods_count': 4},
        {'name': 'التربية الرياضية', 'code': 'رياضة', 'color_hex': '#E91E63', 'weekly_periods_count': 2},
      ];

      for (var sub in subjects) {
        sub['grade_id'] = gradeId;
        sub['max_daily_periods'] = 2;
        await db.insert('subjects', sub);
      }
    }

    List<Map<String, dynamic>> teachers = [
      {'full_name': 'أحمد جاسم سلمان', 'code': 'أ_أحمد', 'target_weekly_quota': 24},
      {'full_name': 'محمد علي حسين', 'code': 'أ_محمد', 'target_weekly_quota': 24},
      {'full_name': 'فاطمة كريم حسن', 'code': 'أ_فاطمة', 'target_weekly_quota': 24},
      {'full_name': 'زينب عبد الزهرة', 'code': 'أ_زينب', 'target_weekly_quota': 24},
      {'full_name': 'حيدر عبود كاظم', 'code': 'أ_حيدر', 'target_weekly_quota': 24},
    ];

    for (var t in teachers) {
      int tId = await db.insert('teachers', t);
      List<Map<String, dynamic>> allSubs = await db.query('subjects');
      for (var sub in allSubs) {
        await db.insert('teacher_subjects', {'teacher_id': tId, 'subject_id': sub['id']});
      }
    }

    await db.insert('timetable_versions', {
      'version_name': 'الجدول المعتمد الأصلي',
      'academic_year': '2026-2027',
      'status': 'approved',
      'created_at': DateTime.now().toIso8601String(),
      'notes': 'الجدول الرئيسي للمدرسة',
    });
  }
}
