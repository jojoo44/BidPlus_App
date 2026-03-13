import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';

class CreateRFPScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialBudget;

  const CreateRFPScreen({super.key, this.initialTitle, this.initialBudget});

  @override
  State<CreateRFPScreen> createState() => _CreateRFPScreenState();
}

class _CreateRFPScreenState extends State<CreateRFPScreen> {
  final Color bgColor = const Color(0xFF0D1219);
  final Color fieldColor = const Color(0xFF1C242F);
  final Color primaryBlue = const Color(0xFF3395FF);

  late TextEditingController titleController;
  late TextEditingController budgetController;
  late TextEditingController descriptionController;
  late TextEditingController deadlineController;

  bool _isLoading = false;

  // ============================================
  // متغيرات الملفات
  // ============================================
  final List<PlatformFile> _pickedFiles = [];
  final List<String> _uploadedUrls = [];
  bool _isUploadingFile = false;

  final List<String> standardCriteria = [
    "Cost",
    "Experience",
    "Technical",
    "Timeline",
  ];

  List<Map<String, String>> criteriaList = [
    {"name": "Cost", "weight": "40"},
    {"name": "Experience", "weight": "60"},
  ];

  List<TextEditingController> weightControllers = [
    TextEditingController(text: "40"),
    TextEditingController(text: "60"),
  ];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle ?? "");
    budgetController = TextEditingController(text: widget.initialBudget ?? "");
    descriptionController = TextEditingController();
    deadlineController = TextEditingController();
  }

  @override
  void dispose() {
    titleController.dispose();
    budgetController.dispose();
    descriptionController.dispose();
    deadlineController.dispose();
    for (var c in weightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) {
      deadlineController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  // ============================================
  // رفع الملفات — متوافق مع Web و Mobile
  // ============================================
  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      allowMultiple: true,
      withData: true, // ← مهم على Web
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploadingFile = true);

    try {
      for (final file in result.files) {
        // على Web نستخدم bytes بدل path
        final fileBytes = file.bytes;
        if (fileBytes == null) continue;

        final userId = supabase.auth.currentUser!.id;
        // اسم فريد يمنع التكرار
        final fileName =
            '$userId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

        // رفع الملف لـ Supabase Storage
        await supabase.storage
            .from('rfp-attachments')
            .uploadBinary(fileName, fileBytes);

        // جيب الرابط العام
        final publicUrl = supabase.storage
            .from('rfp-attachments')
            .getPublicUrl(fileName);

        setState(() {
          _pickedFiles.add(file);
          _uploadedUrls.add(publicUrl);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Files uploaded!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
      _uploadedUrls.removeAt(index);
    });
  }

  // ============================================
  // حفظ الـ RFP + الملفات في Supabase
  // ============================================
  Future<void> _createRFP() async {
    // التحقق من كل الحقول المطلوبة
    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter RFP Title')));
      return;
    }
    if (descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter Description')));
      return;
    }
    if (deadlineController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a Due Date')));
      return;
    }
    if (budgetController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter Budget')));
      return;
    }
    if (criteriaList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one Evaluation Criterion'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      final criteriaJson = criteriaList
          .asMap()
          .entries
          .map((e) => '${e.value["name"]}:${weightControllers[e.key].text}%')
          .join(', ');

      // 1. حفظ الـ RFP
      final rfpResponse = await supabase
          .from('RFP')
          .insert({
            'title': titleController.text.trim(),
            'description': descriptionController.text.trim(),
            'budget': double.tryParse(budgetController.text) ?? 0,
            'deadline': deadlineController.text.isEmpty
                ? null
                : deadlineController.text,
            'status': 'Draft',
            'evaluationCriteria': criteriaJson,
            'creatorUser': userId,
            'creationDate': DateTime.now().toIso8601String().split('T')[0],
          })
          .select('rfpID')
          .single();

      // 2. حفظ الملفات في جدول Document
      for (int i = 0; i < _pickedFiles.length; i++) {
        await supabase.from('Document').insert({
          'fullName': _pickedFiles[i].name,
          'fileURL': _uploadedUrls[i],
          'uploadDate': DateTime.now().toIso8601String().split('T')[0],
          'uploader': userId,
          'uploadType': 'RFP_Attachment',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('RFP created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================
  // الـ UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New RFP',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("RFP Title"),
            _buildTextField("Enter title", controller: titleController),

            _buildLabel("Description"),
            _buildTextField(
              "Provide a detailed project overview...",
              maxLines: 3,
              controller: descriptionController,
            ),

            _buildLabel("Due Date"),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: _buildTextField(
                  "Select a date",
                  controller: deadlineController,
                  suffixIcon: Icons.calendar_today,
                ),
              ),
            ),

            _buildLabel("Budget"),
            _buildTextField(
              "Enter estimated budget",
              controller: budgetController,
              prefixIcon: Icons.attach_money,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 20),
            _buildLabel("Evaluation Criteria"),
            ...criteriaList.asMap().entries.map((entry) {
              int idx = entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildDropdownField(idx)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Wt.",
                        isSmall: true,
                        controller: weightControllers[idx],
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildIconButton(
                      Icons.delete_outline,
                      Colors.redAccent,
                      () {
                        setState(() {
                          criteriaList.removeAt(idx);
                          weightControllers.removeAt(idx);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),

            GestureDetector(
              onTap: () {
                setState(() {
                  criteriaList.add({"name": "Cost", "weight": "0"});
                  weightControllers.add(TextEditingController(text: "0"));
                });
              },
              child: _buildDashedButton("+ Add Criterion"),
            ),

            // ============================================
            // Attachments Section
            // ============================================
            const SizedBox(height: 20),
            _buildLabel("Attachments"),

            // عرض الملفات المرفوعة
            ..._pickedFiles.asMap().entries.map((entry) {
              final idx = entry.key;
              final file = entry.value;
              final sizeKB = (file.size / 1024).toStringAsFixed(1);
              return _buildUploadedFileTile(
                file.name,
                '$sizeKB KB',
                () => _removeFile(idx),
              );
            }),

            // زر رفع الملفات
            GestureDetector(
              onTap: _isUploadingFile ? null : _pickAndUploadFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isUploadingFile
                    ? const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.file_upload_outlined,
                            color: Colors.grey,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "+ Add Attachments",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _createRFP,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Create RFP",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================
  // Widgets المساعدة
  // ============================================
  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 14),
    ),
  );

  Widget _buildTextField(
    String hint, {
    TextEditingController? controller,
    int maxLines = 1,
    IconData? suffixIcon,
    IconData? prefixIcon,
    bool isSmall = false,
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      filled: true,
      fillColor: fieldColor,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.grey, size: 20)
          : null,
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: Colors.grey, size: 20)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _buildDropdownField(int index) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: fieldColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: criteriaList[index]["name"],
        dropdownColor: fieldColor,
        items: standardCriteria
            .map(
              (val) => DropdownMenuItem(
                value: val,
                child: Text(val, style: const TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
        onChanged: (val) => setState(() => criteriaList[index]["name"] = val!),
      ),
    ),
  );

  Widget _buildUploadedFileTile(
    String name,
    String size,
    VoidCallback onRemove,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: fieldColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.description, color: Colors.blue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                size,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, color: Colors.grey, size: 18),
        ),
      ],
    ),
  );

  Widget _buildDashedButton(String label) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Text(label, style: const TextStyle(color: Colors.grey)),
    ),
  );

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      );
}
