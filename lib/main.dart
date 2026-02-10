import 'package:flutter/material.dart';
import 'login_screen.dart'; // هذا المسار الصحيح لأن الملف داخل مجلد auth

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: LoginScreen(), // تأكدي أن الاسم يطابق الكلاس في ملف صديقتك
    );
  }
}
