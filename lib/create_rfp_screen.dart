import 'package:flutter/material.dart';

class CreateRFPScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialBudget;

  const CreateRFPScreen({super.key, this.initialTitle, this.initialBudget});

  @override
  State<CreateRFPScreen> createState() => _CreateRFPScreenState();
}

class _CreateRFPScreenState extends State<CreateRFPScreen> {
  // الألوان المتناسقة مع تصميمك
  final Color bgColor = const Color(0xFF0D1219);
  final Color fieldColor = const Color(0xFF1C242F);
  final Color primaryBlue = const Color(0xFF3395FF);

  // تعريف الـ Controllers (تمت إزالة late لتجنب الأخطاء)
  TextEditingController titleController = TextEditingController();
  TextEditingController budgetController = TextEditingController();

  // قائمة المعايير والمرفقات للتجربة
  final List<String> standardCriteria = [
    "Cost",
    "Experience",
    "Technical",
    "Timeline",
  ];
  List<Map<String, String>> criteriaList = [
    {"name": "Cost", "weight": "40%"},
    {"name": "Experience", "weight": "60%"},
  ];

  @override
  void initState() {
    super.initState();
    // تهيئة النصوص بالقيم القادمة من صفحة التعديل
    titleController = TextEditingController(text: widget.initialTitle ?? "");
    budgetController = TextEditingController(text: widget.initialBudget ?? "");
  }

  @override
  void dispose() {
    titleController.dispose();
    budgetController.dispose();
    super.dispose();
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
            ),

            _buildLabel("Due Date"),
            _buildTextField("Select a date", suffixIcon: Icons.calendar_today),

            _buildLabel("Budget"),
            _buildTextField(
              "Enter estimated budget",
              controller: budgetController,
              prefixIcon: Icons.attach_money,
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
                    Expanded(child: _buildTextField("Wt.", isSmall: true)),
                    const SizedBox(width: 10),
                    _buildIconButton(
                      Icons.delete_outline,
                      Colors.redAccent,
                      () {
                        setState(() => criteriaList.removeAt(idx));
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
            _buildDashedButton("+ Add Criterion"),

            const SizedBox(height: 20),
            _buildLabel("Attachments"),
            _buildAttachmentTile("Project_Brief_v2.pdf", "2.4 MB"),
            _buildDashedButton("+ Add Attachments"),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel("Assign Evaluators"),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "+ Add",
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildAvatarChip("Sarah Day"),
                const SizedBox(width: 8),
                _buildAvatarChip("Alex Johnson"),
              ],
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
                onPressed: () => Navigator.pop(context),
                child: const Text(
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

  // --- دوال بناء العناصر المساعدة (Widgets) ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  Widget _buildTextField(
    String hint, {
    TextEditingController? controller,
    int maxLines = 1,
    IconData? suffixIcon,
    IconData? prefixIcon,
    bool isSmall = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
  }

  Widget _buildDropdownField(int index) {
    return Container(
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
          onChanged: (val) =>
              setState(() => criteriaList[index]["name"] = val!),
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(String name, String size) {
    return Container(
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
                ),
                Text(
                  size,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.close, color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _buildDashedButton(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(label, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildAvatarChip(String name) {
    return Chip(
      backgroundColor: fieldColor,
      avatar: const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, size: 12),
      ),
      label: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.grey),
      onDeleted: () {},
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
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
}
