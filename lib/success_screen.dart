import 'package:flutter/material.dart';
import 'dashboard.dart'; // ملف المانجر (BidPlus)
import 'contractor_dashboard_screen.dart'; // ملف الكونتراكتر

class SuccessScreen extends StatelessWidget {
  final String role; // ✅ استقبال الدور
  const SuccessScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF5D78FF), size: 120),
            const SizedBox(height: 40),
            const Text("Success!", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text(
              "Your account has been successfully created. Welcome to the team!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 60),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D78FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // ✅ التوجيه النهائي بناءً على نوع المستخدم
                  if (role == "Manager") {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const BidPlus()),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const ContractorDashboardScreen()),
                    );
                  }
                },
                child: const Text("Continue", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}