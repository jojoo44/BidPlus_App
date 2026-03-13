import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isManager;
  const EditProfileScreen({super.key, required this.isManager});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specController = TextEditingController();

  String? _selectedTag;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _email;

  final List<Map<String, String>> _tags = [
    {'label': 'Construction', 'value': 'construction'},
    {'label': 'Engineering', 'value': 'engineering'},
    {'label': 'IT & Software', 'value': 'it'},
    {'label': 'Design', 'value': 'design'},
    {'label': 'Maintenance', 'value': 'maintenance'},
    {'label': 'Consulting', 'value': 'consulting'},
    {'label': 'Logistics', 'value': 'logistics'},
    {'label': 'Other', 'value': 'other'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('User')
          .select('username, contactInfo, specialization, specializationTag')
          .eq('id', user.id)
          .single();

      setState(() {
        _email = user.email ?? '';
        _nameController.text = data['username'] ?? '';
        _phoneController.text = data['contactInfo'] ?? '';
        _specController.text = data['specialization'] ?? '';
        _selectedTag = data['specializationTag'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      final updateData = <String, dynamic>{
        'username': _nameController.text.trim(),
        'contactInfo': _phoneController.text.trim(),
      };

      if (!widget.isManager) {
        updateData['specialization'] = _specController.text.trim();
        updateData['specializationTag'] = _selectedTag;
      }

      await supabase.from('User').update(updateData).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF12141D);
    const card = Color(0xFF1E212A);
    const blue = Color(0xFF3395FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          widget.isManager ? 'Edit Account Manager' : 'Edit Account Contractor',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // صورة البروفايل
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 45,
                          backgroundColor: Color(0xFF5D78FF),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 45,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {},
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

                  // الحقول المشتركة
                  _buildTextField(
                    'Full Name',
                    _nameController,
                    'Enter your full name',
                  ),
                  _buildReadOnly('Email Address', _email ?? ''),
                  _buildTextField(
                    'Phone Number',
                    _phoneController,
                    '05xxxxxxxx',
                  ),

                  // حقول الكونتراكتور فقط
                  if (!widget.isManager) ...[
                    const SizedBox(height: 8),
                    _buildTextField(
                      'Your Specialization',
                      _specController,
                      'e.g., Civil Engineering, IT Support...',
                    ),

                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Field / Category',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.map((tag) {
                        final isSelected = _selectedTag == tag['value'];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedTag = tag['value']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? blue : card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? blue : Colors.white12,
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
                  ],

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveChanges,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E212A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildReadOnly(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E212A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}
