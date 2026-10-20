import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_school_timetable/services/auto_scheduler_service.dart';

void main() {
  const scheduler = AutoSchedulerService(nodeLimit: 5000);

  test('يوزع حصتين على يومين دون تكرار المادة في اليوم نفسه', () {
    final result = scheduler.generate(
      sections: [{'id': 1, 'section_name': 'أ', 'max_daily_lessons': 6}],
      requirements: [{'section_id': 1, 'subject_id': 2, 'subject_name': 'الرياضيات', 'weekly_lessons': 2, 'max_daily_lessons': 2, 'allow_same_day': 0}],
      teachers: [{'id': 5, 'name': 'معلم الرياضيات', 'weekly_load': 20, 'max_daily_lessons': 5, 'max_consecutive_lessons': 4}],
      qualifications: [{'teacher_id': 5, 'subject_id': 2}],
      days: [{'id': 1, 'name': 'الأحد', 'position': 0, 'is_active': 1}, {'id': 2, 'name': 'الاثنين', 'position': 1, 'is_active': 1}],
      slots: [{'id': 1, 'name': 'الأولى', 'position': 0, 'kind': 'lesson', 'is_available': 1}],
    );
    expect(result.complete, isTrue);
    expect(result.placements, hasLength(2));
    expect(result.placements.map((e) => e['day_id']).toSet(), hasLength(2));
    expect(result.placements.map((e) => e['teacher_id']).toSet(), equals({5}));
  });

  test('لا يدّعي اكتمال الجدول عندما لا يوجد معلم مؤهل', () {
    final result = scheduler.generate(
      sections: [{'id': 1, 'section_name': 'أ'}],
      requirements: [{'section_id': 1, 'subject_id': 2, 'subject_name': 'العلوم', 'weekly_lessons': 1}],
      teachers: [{'id': 5, 'name': 'معلم'}],
      qualifications: [],
      days: [{'id': 1, 'name': 'الأحد', 'position': 0, 'is_active': 1}],
      slots: [{'id': 1, 'name': 'الأولى', 'position': 0, 'kind': 'lesson', 'is_available': 1}],
    );
    expect(result.complete, isFalse);
    expect(result.placements, isEmpty);
    expect(result.unscheduled, isNotEmpty);
  });
}
