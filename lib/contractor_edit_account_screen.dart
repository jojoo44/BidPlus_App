import 'package:flutter/material.dart';

class ContractorEditAccountScreen extends StatelessWidget {
  const ContractorEditAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141D),
      appBar: AppBar(
        title: const Text('Edit Account'),
        backgroundColor: const Color(0xFF0F1F3A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // Profile Image (UI only)
            // =========================
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 45,
                    backgroundImage:
                        NetworkImage('https://via.placeholder.com/150'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      // شكل فقط – بدون تغيير فعلي
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Coming soon'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF252B3D),
                    ),
                    child: const Text(
                      'Change Photo',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // =========================
            // Form Fields
            // =========================
            _buildTextField(
              label: 'Full Name',
              hint: 'Enter your full name',
            ),
            _buildTextField(
              label: 'Email Address',
              hint: 'example@email.com',
            ),
            _buildTextField(
              label: 'Phone Number',
              hint: '05xxxxxxxx',
              isError: true,
            ),

            const SizedBox(height: 20),

            _buildDropdownField(
              label: 'Professional Specialization',
              value: 'Plumbing',
            ),

            const SizedBox(height: 25),

            _buildSectionLabel('Documents'),

            _buildFileTile('BusinessLicense.pdf'),
            _buildFileTile('LiabilityInsurance.pdf'),

            const SizedBox(height: 40),

            // =========================
            // Save Button
            // =========================
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
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

  // =========================
  // Widgets
  // =========================
  static Widget _buildTextField({
    required String label,
    required String hint,
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1E212A),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isError ? Colors.red : Colors.transparent,
                ),
              ),
            ),
          ),
          if (isError)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'Please enter a valid phone number.',
                style: TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildDropdownField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF1E212A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
            trailing:
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  static Widget _buildFileTile(String fileName) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Re-upload',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}