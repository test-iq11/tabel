import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_school_timetable/models/app_models.dart';

void main() {
  group('اختبارات نماذج البيانات والقيود', () {
    test('اختبار إنشاء نموذج إعدادات المدرسة', () {
      final settings = SchoolSettings(
        schoolName: 'مدرسة الأمل',
        directorateName: 'ذي قار',
        stageName: 'الابتدائية',
        academicYear: '2026-2027',
      );

      expect(settings.schoolName, equals('مدرسة الأمل'));
      expect(settings.workingDaysCount, equals(5));
      expect(settings.dailyPeriodsCount, equals(5));
    });

    test('اختبار تكوين حصص المادة الدراسية', () {
      final subject = Subject(
        name: 'الرياضيات',
        gradeId: 1,
        weeklyPeriodsCount: 5,
      );

      expect(subject.name, equals('الرياضيات'));
      expect(subject.weeklyPeriodsCount, equals(5));
    });
  });
}
