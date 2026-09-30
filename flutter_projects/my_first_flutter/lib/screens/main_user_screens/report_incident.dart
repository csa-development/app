import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/auth_storage.dart';
import '../../widgets/swipe_back.dart';
import '../../widgets/top_toast.dart';
import 'report_incident_2.dart';

class ReportIncidentScreen extends StatefulWidget {
  final String? preselectedType;
  const ReportIncidentScreen({super.key, this.preselectedType});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color fieldBorder = Color(0xFFE4E6EB);
  static const int _descriptionMaxLength = 1000;

  String? selectedIncidentType;
  DateTime? selectedDate;

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final List<String> incidentTypes = [
    'Cyberbullying',
    'Malware',
    'Publication of Non-Consensual Intimate Images',
    'Misinformation',
    'Fraud',
    'Online Blackmail',
    'Online Child Abuse',
    'Online Impersonation',
    'Ransomware',
    'Service Disruption',
    'Dos/DDos',
    'Spam / Phishing',
    'Unauthorized Access',
    'Website Defacement',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedType != null) {
      selectedIncidentType = widget.preselectedType;
    }
    _prefillFromAccount();
    // Repaints the "x / 1000" counter as the user types.
    descriptionController.addListener(_onDescriptionChanged);
  }

  Future<void> _prefillFromAccount() async {
    final fullName = await AuthStorage.getFullName();
    if (!mounted) return;
    setState(() => fullNameController.text = fullName ?? '');
  }

  void _onDescriptionChanged() => setState(() {});

  @override
  void dispose() {
    descriptionController.removeListener(_onDescriptionChanged);
    fullNameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime tempDate = selectedDate ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                      const Text(
                        'Date of Incident',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => selectedDate = tempDate);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempDate,
                    minimumDate: DateTime(2015),
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (date) => tempDate = date,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _handleNext() {
    if (selectedIncidentType == null) {
      showTopToast(context, 'Please select an incident type');
      return;
    }

    if (selectedDate == null) {
      showTopToast(context, 'Please select the date of the incident');
      return;
    }

    if (fullNameController.text.trim().isEmpty) {
      showTopToast(context, 'Please enter your full name');
      return;
    }

    if (descriptionController.text.trim().isEmpty) {
      showTopToast(context, 'Please enter a description');
      return;
    }

    final dateString =
        '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ReportIncident2Screen(
          incidentType: selectedIncidentType!,
          reporterName: fullNameController.text.trim(),
          description: descriptionController.text.trim(),
          dateOfIncident: dateString,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Report Incident',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            

            const SizedBox(height: 24),

            _label('Incident Type'),
            const SizedBox(height: 8),
            _incidentSelector(),

            const SizedBox(height: 20),

            _label('Date of Incident'),
            const SizedBox(height: 8),
            _dateSelector(),

            const SizedBox(height: 20),

            _label('Full Name'),
            const SizedBox(height: 8),
            _plainField(
              child: TextField(
                controller: fullNameController,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  hintText: 'Enter your full name',
                  hintStyle: TextStyle(color: Colors.black45),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _label('Description'),
            const SizedBox(height: 8),
            _plainField(
              child: TextField(
                controller: descriptionController,
                maxLines: 6,
                maxLength: _descriptionMaxLength,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  hintText: 'Describe the incident in detail',
                  hintStyle: TextStyle(color: Colors.black45),
                  counterText: '',
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${descriptionController.text.length} / $_descriptionMaxLength',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _handleNext,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'NEXT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _label(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _plainField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fieldBorder),
      ),
      child: child,
    );
  }

  void _pickIncidentType() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Incident Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: incidentTypes.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: Color(0xFFF0F0F0),
                    ),
                    itemBuilder: (context, index) {
                      final type = incidentTypes[index];
                      final isSelected = type == selectedIncidentType;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          type,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? primaryBlue : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check,
                                color: primaryBlue, size: 20)
                            : null,
                        onTap: () {
                          setState(() => selectedIncidentType = type);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _incidentSelector() {
    return GestureDetector(
      onTap: _pickIncidentType,
      child: _plainField(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedIncidentType ?? 'Select incident type',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: selectedIncidentType != null
                        ? Colors.black87
                        : Colors.black45,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateSelector() {
    return GestureDetector(
      onTap: _pickDate,
      child: _plainField(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedDate != null
                      ? _formatDate(selectedDate!)
                      : 'Select date of incident',
                  style: TextStyle(
                    fontSize: 15,
                    color: selectedDate != null
                        ? Colors.black87
                        : Colors.black45,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
