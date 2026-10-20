import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await DatabaseService.instance.database;
    runApp(const TimetableApp());
  } catch (error) {
    runApp(BootErrorApp(message: error.toString()));
  }
}

class BootErrorApp extends StatelessWidget {
  const BootErrorApp({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text('تعذر تشغيل قاعدة البيانات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8), Text(message, textAlign: TextAlign.center),
          ]),
        )),
      ),
    ),
  );
}
