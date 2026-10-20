import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_school_timetable/services/conflict_detection_service.dart';

void main() {
  const service = ConflictDetectionService();

  test('يكتشف تعارض المعلم في اليوم والفترة نفسيهما', () {
    final issues = service.scan(
      entries: [
        {'id': 1, 'section_id': 1, 'subject_id': 10, 'teacher_id': 7, 'day_id': 1, 'slot_id': 1, 'section_name': 'أ', 'teacher_name': 'أحمد'},
        {'id': 2, 'section_id': 2, 'subject_id': 11, 'teacher_id': 7, 'day_id': 1, 'slot_id': 1, 'section_name': 'ب', 'teacher_name': 'أحمد'},
      ],
      qualifications: [
        {'teacher_id': 7, 'subject_id': 10},
        {'teacher_id': 7, 'subject_id': 11},
      ],
    );
    expect(issues.any((issue) => issue.type == 'تعارض المعلم' && issue.severity == 'خطأ مانع'), isTrue);
  });

  test('يعطي تحذيراً عند وجود حصة بلا معلم', () {
    final issues = service.scan(entries: [
      {'id': 1, 'section_id': 1, 'subject_id': 10, 'teacher_id': null, 'day_id': 1, 'slot_id': 1, 'subject_name': 'الرياضيات'},
    ]);
    expect(issues.any((issue) => issue.type == 'حصة بلا معلم' && issue.severity == 'تحذير'), isTrue);
  });

  test('يكتشف أن الفترة ليست فترة تدريس', () {
    final issues = service.scan(
      entries: [{'id': 1, 'section_id': 1, 'subject_id': 10, 'teacher_id': null, 'day_id': 1, 'slot_id': 4}],
      slots: [{'id': 4, 'name': 'الاستراحة', 'kind': 'break', 'is_available': 0}],
    );
    expect(issues.any((issue) => issue.type == 'فترة غير متاحة' && issue.severity == 'خطأ مانع'), isTrue);
  });
}
