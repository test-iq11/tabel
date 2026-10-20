import 'package:flutter/material.dart';

import '../../core/ui_helpers.dart';
import '../../data/database_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.onNavigate, super.key});
  final ValueChanged<int> onNavigate;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<Map<String, Object?>>? _summary;
  Future<Map<String, Object?>>? _settings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _summary = DatabaseService.instance.summary();
    _settings = DatabaseService.instance.getSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منظّم الجدول المدرسي'),
        actions: [IconButton(onPressed: () => setState(_reload), tooltip: 'تحديث', icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<Map<String, Object?>>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return emptyState(icon: Icons.error_outline, title: 'تعذر تحميل الملخص', message: '${snapshot.error}');
            final data = snapshot.data ?? {};
            final rate = (data['نسبة الاكتمال'] as num?)?.toDouble() ?? 0;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                FutureBuilder<Map<String, Object?>>(
                  future: _settings,
                  builder: (context, settingsSnapshot) {
                    final schoolName = settingsSnapshot.data?['school_name']?.toString() ?? 'مدرستي';
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF183B66), Color(0xFF2878C8)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('مرحباً بك في', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 5), Text(schoolName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8), Text('العام الدراسي ${data['العام الدراسي'] ?? 'غير محدد'}', style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), child: const Text('إدارة محلية دون إنترنت', style: TextStyle(color: Colors.white, fontSize: 12))),
                        ])),
                        const SizedBox(width: 14), Container(width: 66, height: 66, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.calendar_month_rounded, size: 38, color: Colors.white)),
                      ]),
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Text('نظرة عامة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF183B66))),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                  crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.55,
                  children: [
                    _MetricCard(label: 'الصفوف', value: data['عدد الصفوف'], icon: Icons.school_outlined, color: const Color(0xFF2878C8)),
                    _MetricCard(label: 'الشعب', value: data['عدد الشعب'], icon: Icons.groups_2_outlined, color: const Color(0xFF16845B)),
                    _MetricCard(label: 'المواد', value: data['عدد المواد'], icon: Icons.menu_book_outlined, color: const Color(0xFFB87419)),
                    _MetricCard(label: 'المعلمون', value: data['عدد المعلمين'], icon: Icons.co_present_outlined, color: const Color(0xFF7C5AB8)),
                    _MetricCard(label: 'الحصص المطلوبة', value: data['الحصص المطلوبة'], icon: Icons.fact_check_outlined, color: const Color(0xFF2878C8)),
                    _MetricCard(label: 'الحصص الموزعة', value: data['الحصص الموزعة'], icon: Icons.event_available_outlined, color: const Color(0xFF16845B)),
                    _MetricCard(label: 'الحصص المتبقية', value: data['الحصص المتبقية'], icon: Icons.pending_actions_outlined, color: const Color(0xFFB87419)),
                    _MetricCard(label: 'نسبة الاكتمال', value: '${(rate * 100).round()}%', icon: Icons.donut_large_outlined, color: rate >= 1 ? const Color(0xFF16845B) : const Color(0xFF2878C8)),
                  ],
                ),
                const SizedBox(height: 18),
                Card(child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Expanded(child: Text('اكتمال الجدول', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), Text('${(rate * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF183B66)))]),
                    const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: rate, minHeight: 10, backgroundColor: const Color(0xFFE4EBF3), color: rate >= 1 ? const Color(0xFF16845B) : const Color(0xFF2878C8))),
                    const SizedBox(height: 8), Text(rate == 1 ? 'تم توزيع العدد المسجل من الحصص المطلوبة.' : 'أكمل متطلبات المواد ثم أنشئ الجدول أو راجعه يدوياً.', style: const TextStyle(color: Colors.black54)),
                  ]),
                )),
                const SizedBox(height: 18),
                const Text('الوصول السريع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF183B66))),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                  crossAxisSpacing: 10, mainAxisSpacing: 10, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.8,
                  children: [
                    _Shortcut(icon: Icons.tune, label: 'إدارة البيانات', onTap: () => widget.onNavigate(1)),
                    _Shortcut(icon: Icons.calendar_month, label: 'محرر الجدول', onTap: () => widget.onNavigate(2)),
                    _Shortcut(icon: Icons.rule, label: 'فحص التعارضات', onTap: () => widget.onNavigate(3)),
                    _Shortcut(icon: Icons.folder_copy, label: 'التقارير والنسخ', onTap: () => widget.onNavigate(4)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final Object? value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 20)), const Spacer(), Text('${value ?? 0}', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: color))]),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
    ])),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(
    borderRadius: BorderRadius.circular(18), onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      Icon(icon, color: const Color(0xFF2878C8)), const SizedBox(width: 10), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.chevron_left, size: 19),
    ])),
  ));
}
