import 'package:flutter/material.dart';
import 'verify_email_screen.dart';

class SignUpScreen extends StatelessWidget {
  final String role; // نعرف هل هو مدير أو مقاول
  const SignUpScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    bool isManager = role == "Manager";

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF5D78FF)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            // العنوان يتغير حسب الدور
            Text(
              isManager ? "Manager" : "Sign Up",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              isManager ? "Sign up" : "Contractor",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),

            // حقول البيانات
            _buildLabel("Full Name"),
            _buildInput("e.g., Sarah Miller"),

            _buildLabel(isManager ? "Work Email Address" : "Email Address"),
            _buildInput("john@example.com"),

            _buildLabel("Phone Number"),
            _buildInput("(123) 456-7890"),

            _buildLabel("Create Password"),
            _buildInput("Secure input", isPass: true),

            // لو مدير نطلع له حقل اسم الشركة
            if (isManager) ...[
              _buildLabel("Company Name"),
              _buildInput("e.g., Acme Corp."),
            ],

            // لو مقاول نطلع له أزرار رفع الملفات
            if (!isManager) ...[
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Showcase Your Work",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      Icons.file_upload_outlined,
                      "Upload Files",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionBtn(Icons.link, "Add Link")),
                ],
              ),
            ],

            const SizedBox(height: 40),

            // زر التسجيل النهائي
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VerifyEmailScreen(),
                    ),
                  ); // هنا تطلع صفحة Success بعدين!
                },
                child: const Text(
                  "Sign Up",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // أدوات بناء الواجهة
  Widget _buildLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 15),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    ),
  );

  Widget _buildInput(String hint, {bool isPass = false}) => TextField(
    obscureText: isPass,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF161B22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _buildActionBtn(IconData icon, String txt) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.withOpacity(0.1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(txt, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}
