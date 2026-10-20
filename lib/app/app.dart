import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme.dart';
import '../features/conflicts/conflicts_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/data_management/data_management_page.dart';
import '../features/timetable/timetable_page.dart';
import '../features/tools/tools_page.dart';

class TimetableApp extends StatelessWidget {
  const TimetableApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'منظّم الجدول المدرسي العراقي الذكي',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: buildAppTheme(),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _refreshToken = 0;

  void _goTo(int index) => setState(() => _index = index);
  void _refreshApp() => setState(() => _refreshToken++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(key: ValueKey('dashboard-$_refreshToken'), onNavigate: _goTo),
      DataManagementPage(key: ValueKey('data-$_refreshToken'), onChanged: _refreshApp),
      TimetablePage(key: ValueKey('table-$_refreshToken'), onChanged: _refreshApp),
      ConflictsPage(key: ValueKey('conflicts-$_refreshToken')),
      ToolsPage(key: ValueKey('tools-$_refreshToken'), onChanged: _refreshApp),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: IndexedStack(index: _index, children: pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'البيانات'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'الجدول'),
            NavigationDestination(icon: Icon(Icons.rule_outlined), selectedIcon: Icon(Icons.rule), label: 'التعارضات'),
            NavigationDestination(icon: Icon(Icons.folder_copy_outlined), selectedIcon: Icon(Icons.folder_copy), label: 'التقارير'),
          ],
        ),
      ),
    );
  }
}
