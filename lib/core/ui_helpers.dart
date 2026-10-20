import 'package:flutter/material.dart';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message), behavior: SnackBarBehavior.floating,
    backgroundColor: error ? Colors.red.shade700 : const Color(0xFF183B66),
  ));
}

Future<bool> confirmAction(BuildContext context, String title, String message) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title), content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
      ],
    ),
  ) ?? false;
}

Widget emptyState({required IconData icon, required String title, required String message}) =>
  Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: const Color(0xFF8CA3BA)),
      const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    ]),
  ));

Widget pageHeading(String title, String subtitle, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF183B66))),
      const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.black54)),
    ])),
    if (trailing != null) trailing,
  ]),
);
