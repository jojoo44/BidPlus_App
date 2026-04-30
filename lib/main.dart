import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://owzqxkrviqlabtfizjva.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93enF4a3J2aXFsYWJ0Zml6anZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDg2NTksImV4cCI6MjA4NjkyNDY1OX0.FI58FhrqbReC6XXAGrXvkvT7fkCMRfue-EcZkANUjck',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: WelcomeScreen(),
    );
  }
}
