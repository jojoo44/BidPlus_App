import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import 'ahp_calculator.dart';
import 'ahp_dialog.dart';

class CreateRFPScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialBudget;
  final String? initialDescription;
  final String? initialDeadline;
  final String? initialEvaluationCriteria;
  final String? initialRequiredTag;
  final String? rfpId;

  const CreateRFPScreen({
    super.key,
    this.initialTitle,
    this.initialBudget,
    this.initialDescription,
    this.initialDeadline,
    this.initialEvaluationCriteria,
    this.initialRequiredTag,
    this.rfpId,
  });

  @override
  State<CreateRFPScreen> createState() => _CreateRFPScreenState();
}

class _CreateRFPScreenState extends State<CreateRFPScreen> {
  final Color bgColor = const Color(0xFF0D1219);
  final Color fieldColor = const Color(0xFF1C242F);
  final Color primaryBlue = const Color(0xFF3395FF);
  final Color greenColor = const Color(0xFF34D399);

  late TextEditingController titleController;
  late TextEditingController budgetController;
  late TextEditingController descriptionController;
  late TextEditingController deadlineController;
  final TextEditingController _requiredSpecController = TextEditingController();

  String? _selectedRequiredTag;
  bool _isLoading = false;

  final List<PlatformFile> _pickedFiles = [];
  final List<String> _uploadedUrls = [];
  bool _isUploadingFile = false;

  final List<String> standardCriteria = [
    "Cost",
    "Experience",
    "Technical",
    "Timeline",
  ];

  List<Map<String, String>> criteriaList = [];
  List<TextEditingController> weightControllers = [];

  // ── AHP: هل تم حساب الأوزان؟ ──
  bool _ahpApplied = false;
  double? _lastCR;

  final List<Map<String, String>> _tags = [
    {"label": "Construction", "value": "construction"},
    {"label": "Engineering", "value": "engineering"},
    {"label": "IT & Software", "value": "it"},
    {"label": "Design", "value": "design"},
    {"label": "Maintenance", "value": "maintenance"},
    {"label": "Consulting", "value": "consulting"},
    {"label": "Logistics", "value": "logistics"},
    {"label": "Other", "value": "other"},
  ];

  bool get _isEditMode => widget.rfpId != null;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle ?? '');
    budgetController = TextEditingController(text: widget.initialBudget ?? '');
    descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    deadlineController = TextEditingController(
      text: widget.initialDeadline ?? '',
    );
    _selectedRequiredTag = widget.initialRequiredTag;

    if (widget.initialEvaluationCriteria != null &&
        widget.initialEvaluationCriteria!.isNotEmpty) {
      final parts = widget.initialEvaluationCriteria!.split(',');
      for (final part in parts) {
        final trimmed = part.trim();
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx == -1) continue;
        final name = trimmed.substring(0, colonIdx).trim();
        final weight = trimmed
            .substring(colonIdx + 1)
            .trim()
            .replaceAll('%', '');
        criteriaList.add({'name': name, 'weight': weight});
        weightControllers.add(TextEditingController(text: weight));
      }
    }

    if (criteriaList.isEmpty) {
      criteriaList = [
        {'name': 'Cost', 'weight': '40'},
        {'name': 'Experience', 'weight': '60'},
      ];
      weightControllers = [
        TextEditingController(text: '40'),
        TextEditingController(text: '60'),
      ];
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    budgetController.dispose();
    descriptionController.dispose();
    deadlineController.dispose();
    _requiredSpecController.dispose();
    for (var c in weightControllers) c.dispose();
    super.dispose();
  }

  // ── فتح AHP Dialog ──
  Future<void> _openAHPDialog() async {
    if (criteriaList.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least two criteria first')),
      );
      return;
    }

    final names = criteriaList.map((c) => c['name']!).toList();

    final result = await showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AHPDialog(criteria: names),
    );

    if (result == null) return; // المستخدم أغلق بدون تأكيد

    // طبّق الأوزان على الـ controllers
    final percents = AHPCalculator.weightsToPercent(result.values.toList());
    setState(() {
      for (int i = 0; i < criteriaList.length; i++) {
        final name = criteriaList[i]['name']!;
        if (result.containsKey(name)) {
          weightControllers[i].text = percents[i].toString();
          criteriaList[i]['weight'] = percents[i].toString();
        }
      }
      _ahpApplied = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ Weights applied successfully'),
        backgroundColor: greenColor,
      ),
    );
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
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _isUploadingFile = true);
    try {
      for (final file in result.files) {
        final fileBytes = file.bytes;
        if (fileBytes == null) continue;
        final userId = supabase.auth.currentUser!.id;
        final fileName =
            '$userId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        await supabase.storage
            .from('rfp-attachments')
            .uploadBinary(fileName, fileBytes);
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

  void _removeFile(int index) => setState(() {
    _pickedFiles.removeAt(index);
    _uploadedUrls.removeAt(index);
  });

  Future<void> _saveRFP() async {
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
          .map((e) => '${e.value['name']}:${weightControllers[e.key].text}%')
          .join(', ');

      final payload = {
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'budget': double.tryParse(budgetController.text) ?? 0,
        'deadline': deadlineController.text.isEmpty
            ? null
            : deadlineController.text,
        'evaluationCriteria': criteriaJson,
        'requiredSpecialization': _requiredSpecController.text.trim().isEmpty
            ? null
            : _requiredSpecController.text.trim(),
        'requiredTag': _selectedRequiredTag,
      };

      if (_isEditMode) {
        await supabase.from('RFP').update(payload).eq('rfpID', widget.rfpId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('RFP updated!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final newRfp = await supabase
            .from('RFP')
            .insert({
              ...payload,
              'status': 'Draft',
              'creatorUser': userId,
              'creationDate': DateTime.now().toIso8601String().split('T')[0],
            })
            .select('rfpID')
            .single();

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
        title: Text(
          _isEditMode ? 'Edit RFP' : 'New RFP',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('RFP Title'),
            _buildTextField('Enter title', controller: titleController),

            _buildLabel('Description'),
            _buildTextField(
              'Provide a detailed project overview...',
              maxLines: 3,
              controller: descriptionController,
            ),

            _buildLabel('Due Date'),
            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: _buildTextField(
                  'Select a date',
                  controller: deadlineController,
                  suffixIcon: Icons.calendar_today,
                ),
              ),
            ),

            _buildLabel('Budget'),
            _buildTextField(
              'Enter estimated budget',
              controller: budgetController,
              prefixIcon: Icons.attach_money,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 8),
            _buildLabel('Required Specialization (Optional)'),
            _buildTextField(
              'e.g., Civil Engineering, Software Developer...',
              controller: _requiredSpecController,
            ),

            const SizedBox(height: 12),
            _buildLabel('Field / Category (Optional)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final isSelected = _selectedRequiredTag == tag['value'];
                return GestureDetector(
                  onTap: () => setState(
                    () =>
                        _selectedRequiredTag = isSelected ? null : tag['value'],
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : fieldColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? primaryBlue : Colors.white12,
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

            const SizedBox(height: 20),

            // ── Evaluation Criteria Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('Evaluation Criteria'),
                // ── زر AHP ──
                GestureDetector(
                  onTap: _openAHPDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _ahpApplied
                          ? greenColor.withOpacity(0.15)
                          : primaryBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _ahpApplied
                            ? greenColor.withOpacity(0.5)
                            : primaryBlue.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _ahpApplied
                              ? Icons.check_circle_outline
                              : Icons.auto_fix_high,
                          color: _ahpApplied ? greenColor : primaryBlue,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _ahpApplied ? 'AHP ✓' : 'Set weights with AHP',
                          style: TextStyle(
                            color: _ahpApplied ? greenColor : primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // إشعار لو AHP مطبق
            if (_ahpApplied)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Weights set by AHP — you can still adjust them manually',
                  style: TextStyle(
                    color: greenColor.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ),

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
                        'Wt.',
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
                          if (_ahpApplied) _ahpApplied = false;
                        });
                      },
                    ),
                  ],
                ),
              );
            }),

            GestureDetector(
              onTap: () => setState(() {
                criteriaList.add({'name': 'Cost', 'weight': '0'});
                weightControllers.add(TextEditingController(text: '0'));
                if (_ahpApplied) _ahpApplied = false;
              }),
              child: _buildDashedButton('+ Add Criterion'),
            ),

            const SizedBox(height: 20),
            _buildLabel('Attachments'),
            ..._pickedFiles.asMap().entries.map((entry) {
              final idx = entry.key;
              final file = entry.value;
              return _buildUploadedFileTile(
                file.name,
                '${(file.size / 1024).toStringAsFixed(1)} KB',
                () => _removeFile(idx),
              );
            }),

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
                            '+ Add Attachments',
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
                onPressed: _isLoading ? null : _saveRFP,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEditMode ? 'Save Changes' : 'Create RFP',
                        style: const TextStyle(
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
        value: criteriaList[index]['name'],
        dropdownColor: fieldColor,
        items: standardCriteria
            .map(
              (val) => DropdownMenuItem(
                value: val,
                child: Text(val, style: const TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
        onChanged: (val) => setState(() => criteriaList[index]['name'] = val!),
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
