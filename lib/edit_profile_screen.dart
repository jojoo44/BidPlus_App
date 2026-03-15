import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isManager;
  final String initialName;
  final String initialEmail;
  final String initialContact;
  final String initialCompany;

  const EditProfileScreen({
    super.key,
    required this.isManager,
    this.initialName = '',
    this.initialEmail = '',
    this.initialContact = '',
    this.initialCompany = '',
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _contactController;
  late final TextEditingController _companyController;
  bool _isSaving = false;
  bool _isLoading = true;
  Uint8List? _imageBytes; // الصورة المختارة
  String? _photoUrl; // رابط الصورة من Supabase

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _contactController = TextEditingController(text: widget.initialContact);
    _companyController = TextEditingController(text: widget.initialCompany);
    _loadExtraData();
  }

  Future<void> _loadExtraData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await supabase
          .from('User')
          .select('phoneNumber, companyName, photoUrl')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _contactController.text = data['phoneNumber'] ?? '';
          _companyController.text = data['companyName'] ?? '';
          _photoUrl = data['photoUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====================================================
  // اختيار صورة ورفعها على Supabase Storage
  // ====================================================
  Future<void> _pickAndUploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      setState(() => _imageBytes = bytes);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final filePath = 'avatars/$userId.jpg';

      await supabase.storage
          .from('profiles')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final url = supabase.storage.from('profiles').getPublicUrl(filePath);
      await supabase.from('User').update({'photoUrl': url}).eq('id', userId);

      if (mounted) {
        setState(() => _photoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase
          .from('User')
          .update({
            'username': _nameController.text.trim(),
            'phoneNumber': _contactController.text.trim(),
            'companyName': _companyController.text.trim(),
          })
          .eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141D),
      appBar: AppBar(
        title: Text(
          widget.isManager ? "Edit Account Manager" : "Edit Account Contractor",
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickAndUploadPhoto,
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.deepPurple,
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!)
                                : (_photoUrl != null
                                      ? NetworkImage(_photoUrl!)
                                            as ImageProvider
                                      : null),
                            child: _imageBytes == null && _photoUrl == null
                                ? Text(
                                    widget.initialName.isNotEmpty
                                        ? widget.initialName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _pickAndUploadPhoto,
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

                  _buildTextField(
                    "Full Name",
                    "Jane Doe",
                    controller: _nameController,
                  ),
                  _buildTextField(
                    "Email Address",
                    "jane.doe@example.com",
                    controller: _emailController,
                    readOnly: true,
                  ),
                  _buildTextField(
                    "Phone Number",
                    "Enter your phone number",
                    controller: _contactController,
                  ),

                  if (widget.isManager)
                    _buildTextField(
                      "Company Name",
                      "Creative Solutions Inc.",
                      controller: _companyController,
                    ),

                  if (!widget.isManager) ...[
                    _buildDropdownField(
                      "Professional Specialization",
                      "Plumbing",
                    ),
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
                      onPressed: _isSaving ? null : _saveChanges,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
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

  Widget _buildTextField(
    String label,
    String hint, {
    required TextEditingController controller,
    bool isError = false,
    bool readOnly = false,
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
            controller: controller,
            readOnly: readOnly,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: readOnly
                  ? const Color(0xFF161920)
                  : const Color(0xFF1E212A),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isError ? Colors.red : Colors.transparent,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
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

  Widget _buildDropdownField(String label, String value) => Column(
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

  Widget _buildFileTile(String fileName) => Container(
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
          child: const Text("Re-upload", style: TextStyle(color: Colors.grey)),
        ),
      ],
    ),
  );

  Widget _buildSectionLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}
