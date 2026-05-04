import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'success_screen.dart';

import '../main.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String role;

  final String email;

  const VerifyEmailScreen({super.key, required this.role, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());

  final _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;

  bool _hasError = false;

  String? _errorMessage;

  int _resendCooldown = 0;

  Timer? _cooldownTimer;

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();

    for (final f in _focusNodes) f.dispose();

    _cooldownTimer?.cancel();

    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOTP() async {
    if (_otp.length < 6) {
      setState(() {
        _hasError = true;

        _errorMessage = 'Please enter the complete 6-digit code.';
      });

      return;
    }

    setState(() {
      _isLoading = true;

      _hasError = false;

      _errorMessage = null;
    });

    try {
      await supabase.auth.verifyOTP(
        email: widget.email,

        token: _otp,

        type: OtpType.signup,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,

          MaterialPageRoute(builder: (_) => SuccessScreen(role: widget.role)),
        );
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();

      String userMessage;

      if (msg.contains('expired') || msg.contains('otp has expired')) {
        userMessage =
            'Verification code has expired. Please request a new one.';
      } else if (msg.contains('invalid') ||
          msg.contains('incorrect') ||
          msg.contains('token') ||
          msg.contains('otp')) {
        userMessage =
            'Incorrect verification code. Please check and try again.';
      } else {
        userMessage = e.message;
      }

      setState(() {
        _hasError = true;

        _errorMessage = userMessage;
      });

      _clearBoxes();
    } catch (e) {
      setState(() {
        _hasError = true;

        _errorMessage = 'Something went wrong. Please try again.';
      });

      _clearBoxes();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;

    try {
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);

      setState(() {
        _hasError = false;

        _errorMessage = null;

        _resendCooldown = 60;
      });

      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();

          return;
        }

        setState(() {
          _resendCooldown--;

          if (_resendCooldown <= 0) t.cancel();
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code resent! Check your email.'),

          backgroundColor: Colors.green,

          behavior: SnackBarBehavior.floating,
        ),
      );

      _clearBoxes();
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),

          backgroundColor: Colors.redAccent,

          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearBoxes() {
    for (final c in _controllers) c.clear();

    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),

      appBar: AppBar(
        backgroundColor: Colors.transparent,

        elevation: 0,

        leading: const BackButton(color: Color(0xFF5D78FF)),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),

        child: Column(
          children: [
            const SizedBox(height: 40),

            const Icon(
              Icons.mark_email_read_outlined,

              color: Color(0xFF5D78FF),

              size: 80,
            ),

            const SizedBox(height: 30),

            const Text(
              "Verify your email",

              style: TextStyle(
                color: Colors.white,

                fontSize: 24,

                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              widget.email,

              style: const TextStyle(
                color: Color(0xFF5D78FF),

                fontSize: 14,

                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Please enter the 6-digit code sent to your email address.",

              textAlign: TextAlign.center,

              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: List.generate(6, (i) => _buildCodeBox(i)),
            ),

            const SizedBox(height: 16),

            if (_hasError && _errorMessage != null)
              Container(
                width: double.infinity,

                padding: const EdgeInsets.symmetric(
                  horizontal: 14,

                  vertical: 12,
                ),

                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),

                  borderRadius: BorderRadius.circular(10),

                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),

                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,

                      color: Colors.redAccent,

                      size: 18,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        _errorMessage!,

                        style: const TextStyle(
                          color: Colors.redAccent,

                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

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

                onPressed: _isLoading ? null : _verifyOTP,

                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Verify Now",

                        style: TextStyle(
                          color: Colors.white,

                          fontSize: 16,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: _resendCooldown > 0 ? null : _resendCode,

              child: Text(
                _resendCooldown > 0
                    ? 'Resend Code (${_resendCooldown}s)'
                    : 'Resend Code',

                style: TextStyle(
                  color: _resendCooldown > 0
                      ? Colors.grey
                      : const Color(0xFF5D78FF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    return Container(
      width: 46,

      height: 56,

      decoration: BoxDecoration(
        color: const Color(0xFF161B22),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: _hasError
              ? Colors.redAccent.withOpacity(0.6)
              : Colors.transparent,
        ),
      ),

      child: Focus(
        focusNode: _focusNodes[index],

        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();

            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },

        child: TextField(
          controller: _controllers[index],

          autofocus: index == 0,

          textAlign: TextAlign.center,

          keyboardType: TextInputType.number,

          maxLength: 1,

          style: const TextStyle(
            color: Colors.white,

            fontSize: 22,

            fontWeight: FontWeight.bold,
          ),

          decoration: const InputDecoration(
            counterText: "",

            border: InputBorder.none,
          ),

          onChanged: (value) {
            if (_hasError) {
              setState(() {
                _hasError = false;

                _errorMessage = null;
              });
            }

            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            }

            if (index == 5 && value.isNotEmpty) _verifyOTP();
          },
        ),
      ),
    );
  }
}
