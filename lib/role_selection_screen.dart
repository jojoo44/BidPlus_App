import 'package:flutter/material.dart';
import 'signup_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // هذا المتغير عشان نعرف وش اختار المستخدم (Contractor أو Manager)
  String selectedRole = "Contractor";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF5D78FF),
              size: 70,
            ),
            const SizedBox(height: 30),
            const Text(
              "How will you be using this app?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            // بطاقة المدير
            _roleCard(
              "Manager",
              "Create projects and assign tasks",
              Icons.person_outline,
            ),
            const SizedBox(height: 20),

            // بطاقة المقاول
            _roleCard(
              "Contractor",
              "View tasks and update progress",
              Icons.build_outlined,
            ),

            const Spacer(),

            // زر المتابعة
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D78FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  print("Selected Role: $selectedRole");
                  // هنا بنربطها بصفحة التسجيل التفصيلية في الخطوة الجاية
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SignUpScreen(role: selectedRole),
                    ),
                  );
                },
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(String title, String sub, IconData icon) {
    bool isMe = selectedRole == title;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = title),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isMe ? const Color(0xFF5D78FF) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            if (isMe) const Icon(Icons.check_circle, color: Color(0xFF5D78FF)),
          ],
        ),
      ),
    );
  }
}
