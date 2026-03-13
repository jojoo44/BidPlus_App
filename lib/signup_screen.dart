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
  final _specializationController = TextEditingController();

  String? _selectedTag;
  bool _isLoading = false;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _specializationError;

  // التاقز المتاحة
  final List<Map<String, String>> _tags = [
    {'label': 'بناء وتشييد', 'value': 'construction'},
    {'label': 'هندسة', 'value': 'engineering'},
    {'label': 'تقنية معلومات', 'value': 'it'},
    {'label': 'تصميم', 'value': 'design'},
    {'label': 'صيانة', 'value': 'maintenance'},
    {'label': 'استشارات', 'value': 'consulting'},
    {'label': 'لوجستيات', 'value': 'logistics'},
    {'label': 'أخرى', 'value': 'other'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _companyController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
      _specializationError = null;
    });

    bool isValid = true;

    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Full name is required.');
      isValid = false;
    } else if (_nameController.text.trim().length < 3) {
      setState(() => _nameError = 'Name must be at least 3 characters.');
      isValid = false;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = 'Email is required.');
      isValid = false;
    } else if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email address.');
      isValid = false;
    }

    if (_phoneController.text.trim().isEmpty) {
      setState(() => _phoneError = 'Phone number is required.');
      isValid = false;
    } else if (_phoneController.text.trim().length < 9) {
      setState(() => _phoneError = 'Please enter a valid phone number.');
      isValid = false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      isValid = false;
    } else if (_passwordController.text.length < 6) {
      setState(
        () => _passwordError = 'Password must be at least 6 characters.',
      );
      isValid = false;
    }

    // للكونتراكتور فقط
    if (widget.role != 'Manager') {
      if (_specializationController.text.trim().isEmpty) {
        setState(
          () => _specializationError = 'Please describe your specialization.',
        );
        isValid = false;
      }
      if (_selectedTag == null) {
        setState(() => _specializationError = 'Please select a field.');
        isValid = false;
      }
    }

    return isValid;
  }

  Future<void> _signUp() async {
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

      // تحديث بيانات المستخدم
      final updateData = <String, dynamic>{
        'contactInfo': _phoneController.text.trim(),
      };

      if (widget.role != 'Manager') {
        updateData['specialization'] = _specializationController.text.trim();
        updateData['specializationTag'] = _selectedTag;
      }

      await supabase.from('User').update(updateData).eq('id', res.user!.id);

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
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('already exists')) {
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

  @override
  Widget build(BuildContext context) {
    final isManager = widget.role == 'Manager';

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
              isManager ? 'Manager' : 'Sign Up',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              isManager ? 'Sign up' : 'Contractor',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),

            _buildLabel('Full Name'),
            _buildInput(
              'e.g., Sarah Miller',
              controller: _nameController,
              errorText: _nameError,
            ),

            _buildLabel(isManager ? 'Work Email Address' : 'Email Address'),
            _buildInput(
              'john@example.com',
              controller: _emailController,
              errorText: _emailError,
            ),

            _buildLabel('Phone Number'),
            _buildInput(
              '(123) 456-7890',
              controller: _phoneController,
              errorText: _phoneError,
              keyboardType: TextInputType.phone,
            ),

            _buildLabel('Create Password'),
            _buildInput(
              'Secure input',
              isPass: true,
              controller: _passwordController,
              errorText: _passwordError,
            ),

            if (isManager) ...[
              _buildLabel('Company Name'),
              _buildInput('e.g., Acme Corp.', controller: _companyController),
            ],

            // ============================================
            // قسم التخصص — للكونتراكتور فقط
            // ============================================
            if (!isManager) ...[
              const SizedBox(height: 10),
              _buildLabel('Your Specialization'),
              _buildInput(
                'e.g., Civil Engineering, Catering, IT Support...',
                controller: _specializationController,
                errorText: _specializationError,
              ),

              const SizedBox(height: 12),
              _buildLabel('Field / Category'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  final isSelected = _selectedTag == tag['value'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTag = tag['value']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5D78FF)
                            : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5D78FF)
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        tag['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_specializationError != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _specializationError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showcase Your Work',
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
                      'Upload Files',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionBtn(Icons.link, 'Add Link')),
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
                        'Sign Up',
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
        onChanged: (_) => setState(() {
          _nameError = null;
          _emailError = null;
          _phoneError = null;
          _passwordError = null;
          _specializationError = null;
        }),
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
