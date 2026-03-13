import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  final bool isManager;

  const EditProfileScreen({super.key, required this.isManager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141D),
      appBar: AppBar(
        title: Text(
          isManager ? "Edit Account Manager" : "Edit Account Contractor",
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // صورة البروفايل مع زر التغيير
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 45,
                    backgroundImage: NetworkImage(
                      'https://via.placeholder.com/150',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF252B3D),
                    ),
                    child: const Text(
                      "Change Photo",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // الحقول المشتركة
            _buildTextField("Full Name", "Jane Doe"),
            _buildTextField("Email Address", "jane.doe@example.com"),
            _buildTextField(
              "Phone Number",
              "Enter your phone number",
              isError: true,
            ),

            // حقل خاص بالمدير فقط
            if (isManager)
              _buildTextField("Company Name", "Creative Solutions Inc."),

            // حقول خاصة بالمقاول فقط
            if (!isManager) ...[
              _buildDropdownField("Professional Specialization", "Plumbing"),
              const SizedBox(height: 20),
              _buildSectionLabel("Update Documents"),
              _buildFileTile("BusinessLicense.pdf"),
              _buildFileTile("LiabilityInsurance.pdf"),
            ],

            const SizedBox(height: 40),
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
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Save Changes",
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

  Widget _buildTextField(String label, String hint, {bool isError = false}) {
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
                "Please enter a valid phone number.",
                style: TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String value) {
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
            title: Text(value, style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildFileTile(String fileName) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(fileName, style: const TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "Re-upload",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
