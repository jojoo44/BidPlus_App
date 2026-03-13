import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'verify_email_screen.dart';
import '../main.dart';

class SignUpScreen extends StatefulWidget {
  final String role;
  const SignUpScreen({super.key, required this.role});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyController = TextEditingController();

  bool _isLoading = false;

  // أخطاء لكل حقل
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  // ============================================
  // 1. التحقق من صحة المدخلات
  // ============================================
  bool _validateInputs() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
    });

    bool isValid = true;

    // الاسم
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Full name is required.');
      isValid = false;
    } else if (_nameController.text.trim().length < 3) {
      setState(() => _nameError = 'Name must be at least 3 characters.');
      isValid = false;
    }

    // الإيميل
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = 'Email is required.');
      isValid = false;
    } else if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email address.');
      isValid = false;
    }

    // رقم الجوال
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _phoneError = 'Phone number is required.');
      isValid = false;
    } else if (_phoneController.text.trim().length < 9) {
      setState(() => _phoneError = 'Please enter a valid phone number.');
      isValid = false;
    }

    // كلمة المرور
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      isValid = false;
    } else if (_passwordController.text.length < 6) {
      setState(
        () => _passwordError = 'Password must be at least 6 characters.',
      );
      isValid = false;
    }

    return isValid;
  }

  // ============================================
  // 2. دالة التسجيل مع معالجة الأخطاء
  // ============================================
  Future<void> _signUp() async {
    // تحقق من المدخلات أولاً
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      final res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'username': _nameController.text.trim(),
          'role': widget.role.toLowerCase(),
        },
      );

      if (res.user == null) throw Exception('Signup failed. Please try again.');

      await supabase
          .from('User')
          .update({'contactInfo': _phoneController.text.trim()})
          .eq('id', res.user!.id);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              role: widget.role,
              email: _emailController.text.trim(),
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      // ============================================
      // 2. معالجة أخطاء Supabase Auth
      // ============================================
      final msg = e.message.toLowerCase();

      if (msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('user already')) {
        // إيميل مسجّل مسبقاً
        setState(
          () => _emailError =
              'Email already exists. Please log in or use a different email.',
        );
      } else if (msg.contains('invalid email')) {
        setState(() => _emailError = 'Please enter a valid email address.');
      } else if (msg.contains('password') || msg.contains('weak')) {
        setState(
          () => _passwordError =
              'Password is too weak. Use at least 6 characters.',
        );
      } else {
        _showError(e.message);
      }
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================
  // UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    final isManager = widget.role == "Manager";

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

            _buildLabel("Full Name"),
            _buildInput(
              "e.g., Sarah Miller",
              controller: _nameController,
              errorText: _nameError,
            ),

            _buildLabel(isManager ? "Work Email Address" : "Email Address"),
            _buildInput(
              "john@example.com",
              controller: _emailController,
              errorText: _emailError,
            ),

            _buildLabel("Phone Number"),
            _buildInput(
              "(123) 456-7890",
              controller: _phoneController,
              errorText: _phoneError,
              keyboardType: TextInputType.phone,
            ),

            _buildLabel("Create Password"),
            _buildInput(
              "Secure input",
              isPass: true,
              controller: _passwordController,
              errorText: _passwordError,
            ),

            if (isManager) ...[
              _buildLabel("Company Name"),
              _buildInput("e.g., Acme Corp.", controller: _companyController),
            ],

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
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
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

  // ============================================
  // Widgets مساعدة
  // ============================================
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

  Widget _buildInput(
    String hint, {
    bool isPass = false,
    TextEditingController? controller,
    String? errorText,
    TextInputType? keyboardType,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        obscureText: isPass,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        // يمسح الـ error لما يبدأ يكتب
        onChanged: (_) {
          if (errorText != null)
            setState(() {
              _nameError = null;
              _emailError = null;
              _phoneError = null;
              _passwordError = null;
            });
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF161B22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: errorText != null
                ? const BorderSide(color: Colors.redAccent)
                : BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: errorText != null
                ? const BorderSide(color: Colors.redAccent)
                : BorderSide.none,
          ),
        ),
      ),
      // رسالة الخطأ تحت الحقل
      if (errorText != null) ...[
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                errorText,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ],
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
