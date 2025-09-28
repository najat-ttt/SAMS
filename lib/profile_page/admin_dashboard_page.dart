import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import '../login_page/login_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Increased from 4 to 5 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: "Logout",
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Students'),
            Tab(icon: Icon(Icons.book), text: 'Courses'),
            Tab(icon: Icon(Icons.assignment_ind), text: 'Assignments'),
            Tab(icon: Icon(Icons.person_add), text: 'Users'),
            Tab(icon: Icon(Icons.approval), text: 'Approvals'), // New Approvals tab
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StudentManagementTab(),
          _CourseManagementTab(),
          _AssignmentManagementTab(),
          _UserManagementTab(),
          _ApprovalManagementTab(), // New Approvals tab content
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }
}

class _StudentManagementTab extends StatefulWidget {
  @override
  State<_StudentManagementTab> createState() => _StudentManagementTabState();
}

class _StudentManagementTabState extends State<_StudentManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _seriesController = TextEditingController();
  String _selectedSection = 'A';
  bool _isLoading = false;

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      final roll = _rollController.text.trim();

      // Store in section-wise structure: students/{section}/{roll_number}
      await FirebaseFirestore.instance
          .collection('student') // Using flat 'students' collection
          .doc(_selectedSection) // Section as document ID (A, B, C)
          .collection('section_students') // Students subcollection for this section
          .doc(roll) // Using roll as document ID
          .set({
        'roll': roll,
        'name': 'Manual Entry', // Default name for manual entry
        'studentName': 'Manual Entry', // Keep both for compatibility
        'series': _seriesController.text.trim(),
        'department': 'CSE',
        'email': '$roll@student.ruet.ac.bd',
        'section': _selectedSection,
        'registeredAt': FieldValue.serverTimestamp(),
      });

      // Also maintain the flat structure for backward compatibility
      await FirebaseFirestore.instance
          .collection('student') // Flat collection
          .doc(roll)
          .set({
        'roll': roll,
        'name': 'Manual Entry',
        'studentName': 'Manual Entry',
        'series': _seriesController.text.trim(),
        'department': 'CSE',
        'email': '$roll@student.ruet.ac.bd',
        'section': _selectedSection,
        'registeredAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully!')),
      );
      _rollController.clear();
      _seriesController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding student: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _importStudentsFromExcel() async {
    setState(() { _isLoading = true; });
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls']
      );
      if (result == null || result.files.isEmpty) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
        return;
      }

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file data')),
        );
        return;
      }

      final excelFile = excel.Excel.decodeBytes(fileBytes);
      final sheet = excelFile.tables[excelFile.tables.keys.first];
      if (sheet == null) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel file has no data sheets')),
        );
        return;
      }

      print('Excel file loaded successfully with ${sheet.rows.length} rows');

      // Find column indexes based on your data structure
      final header = sheet.rows.first.map((cell) {
        if (cell == null || cell.value == null) return '';
        return cell.value.toString().toLowerCase().trim();
      }).toList();

      print('Excel headers found: $header');

      int slNoIdx = -1, admissionRollIdx = -1, meritIdx = -1,
          studentNameIdx = -1, classRollIdx = -1;

      for (int i = 0; i < header.length; i++) {
        final col = header[i].replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (col.contains('slno') || col.contains('serialno')) slNoIdx = i;
        if (col.contains('admissionroll')) admissionRollIdx = i;
        if (col.contains('merit')) meritIdx = i;
        // Fix: Be very specific about student name and exclude father
        if ((col.contains('studentname') || col == 'name') && !col.contains('father')) studentNameIdx = i;
        if (col.contains('classroll') || (col.contains('roll') && !col.contains('admission'))) classRollIdx = i;
      }

      print('Column indexes found: slNo=$slNoIdx, admission=$admissionRollIdx, merit=$meritIdx, name=$studentNameIdx, roll=$classRollIdx');

      if (classRollIdx == -1 || studentNameIdx == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel must have Student Name and Class Roll columns. Found headers: ${header.join(", ")}')),
        );
        setState(() { _isLoading = false; });
        return;
      }

      // Upload each student record
      int successCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final slNo = row.length > slNoIdx && slNoIdx >= 0 ?
        row[slNoIdx]?.value?.toString().trim() ?? '' : '';
        final admissionRoll = row.length > admissionRollIdx && admissionRollIdx >= 0 ?
        row[admissionRollIdx]?.value?.toString().trim() ?? '' : '';
        final merit = row.length > meritIdx && meritIdx >= 0 ?
        row[meritIdx]?.value?.toString().trim() ?? '' : '';
        final studentName = row.length > studentNameIdx ?
        row[studentNameIdx]?.value?.toString().trim() ?? '' : '';
        final classRoll = row.length > classRollIdx ?
        row[classRollIdx]?.value?.toString().trim() ?? '' : '';

        if (studentName.isEmpty || classRoll.isEmpty) {
          print('Skipping row $i: missing name or roll (name="$studentName", roll="$classRoll")');
          continue;
        }

        // Extract series from class roll (first 2 digits)
        String series = '';
        if (classRoll.length >= 2) {
          series = classRoll.substring(0, 2);
        }

        if (series.isEmpty) {
          errors.add('Row $i: Could not extract series from roll "$classRoll"');
          errorCount++;
          continue;
        }

        // Determine section based on roll number ranges
        String section = 'C'; // Default to C section
        if (classRoll.length >= 7) {
          // Parse the numeric part of the roll (e.g., "2203001" -> 2203001)
          final rollNumber = int.tryParse(classRoll);
          if (rollNumber != null) {
            // Extract the last 3 digits to determine section within any series
            final lastThreeDigits = rollNumber % 1000;

            if (lastThreeDigits >= 1 && lastThreeDigits <= 60) {
              section = 'A';
            } else if (lastThreeDigits >= 61 && lastThreeDigits <= 120) {
              section = 'B';
            } else {
              section = 'C';
            }
          }
        }

        try {
          print('Uploading student: $studentName (Roll: $classRoll, Series: $series, Section: $section)');

          // Store in section-wise structure: students/{section}/{roll_number}
          await FirebaseFirestore.instance
              .collection('student') // Using flat 'students' collection
              .doc(section) // Section as document ID (A, B, C)
              .collection('section_students') // Students subcollection for this section
              .doc(classRoll) // Using class roll as document ID
              .set({
            'roll': classRoll,
            'name': studentName, // Using 'name' field for consistency with reports/attendance
            'studentName': studentName, // Keep both for compatibility
            'admissionRoll': admissionRoll,
            'merit': merit.isNotEmpty ? int.tryParse(merit) : null,
            'slNo': slNo.isNotEmpty ? int.tryParse(slNo) : null,
            'series': series,
            'department': 'CSE',
            'email': '$classRoll@student.ruet.ac.bd',
            'section': section,
            'registeredAt': FieldValue.serverTimestamp(),
          });

          // Also maintain the flat structure for backward compatibility
          await FirebaseFirestore.instance
              .collection('students') // Flat collection
              .doc(classRoll)
              .set({
            'roll': classRoll,
            'name': studentName,
            'studentName': studentName,
            'admissionRoll': admissionRoll,
            'merit': merit.isNotEmpty ? int.tryParse(merit) : null,
            'slNo': slNo.isNotEmpty ? int.tryParse(slNo) : null,
            'series': series,
            'department': 'CSE',
            'email': '$classRoll@student.ruet.ac.bd',
            'section': section,
            'registeredAt': FieldValue.serverTimestamp(),
          });

          successCount++;
          print('Successfully uploaded student: $studentName to section $section');
        } catch (e) {
          print('Error uploading student $studentName ($classRoll): $e');
          errors.add('Row $i ($studentName): $e');
          errorCount++;
        }
      }

      String message = 'Import completed: $successCount students imported successfully';
      if (errorCount > 0) {
        message += ', $errorCount errors occurred';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );

      if (errors.isNotEmpty && errors.length <= 5) {
        // Show first few errors in console
        print('Import errors:');
        for (String error in errors.take(5)) {
          print('  $error');
        }
      }
    } catch (e) {
      print('Excel import error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing students: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Student', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rollController,
                            decoration: const InputDecoration(labelText: 'Roll Number'),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _seriesController,
                            decoration: const InputDecoration(labelText: 'Series'),
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedSection,
                            decoration: const InputDecoration(labelText: 'Section'),
                            items: ['A', 'B', 'C'].map((section) =>
                                DropdownMenuItem(value: section, child: Text(section))
                            ).toList(),
                            onChanged: (value) => setState(() => _selectedSection = value ?? 'A'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _addStudent,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                              : const Text('Add Student'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _importStudentsFromExcel,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Import from Excel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Students List', style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Expanded(child: _StudentsListView()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsListView extends StatefulWidget {
  @override
  State<_StudentsListView> createState() => _StudentsListViewState();
}

class _StudentsListViewState extends State<_StudentsListView> {
  List<Map<String, dynamic>> allStudents = [];
  bool isLoading = true;
  String? selectedSeries;
  String? selectedSection;

  final List<String> series = ["20", "21", "22", "23", "24"];
  final List<String> sections = ["A", "B", "C"];

  @override
  void initState() {
    super.initState();
    _loadAllStudents();
  }

  Future<void> _loadAllStudents() async {
    setState(() { isLoading = true; });
    try {
      List<Map<String, dynamic>> students = [];

      // Load students from all series
      for (String seriesYear in series) {
        final seriesDoc = 'series-$seriesYear';
        final querySnapshot = await FirebaseFirestore.instance
            .collection('student')
            .doc(seriesDoc)
            .collection('students')
            .orderBy('roll')
            .get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          students.add({
            'id': doc.id,
            'roll': data['roll'] ?? doc.id,
            'name': data['studentName'] ?? data['name'] ?? 'Unknown',
            'section': data['section'] ?? 'Unknown',
            'series': seriesYear,
            'email': data['email'] ?? '',
            'department': data['department'] ?? 'CSE',
            'admissionRoll': data['admissionRoll'] ?? '',
            'merit': data['merit'],
          });
        }
      }

      setState(() {
        allStudents = students;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get filteredStudents {
    return allStudents.where((student) {
      bool matchesSeries = selectedSeries == null || student['series'] == selectedSeries;
      bool matchesSection = selectedSection == null || student['section'] == selectedSection;
      return matchesSeries && matchesSection;
    }).toList();
  }

  Future<void> _deleteStudent(String series, String rollId) async {
    try {
      await FirebaseFirestore.instance
          .collection('student')
          .doc('series-$series')
          .collection('students')
          .doc(rollId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted successfully')),
      );

      // Reload students
      _loadAllStudents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting student: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final students = filteredStudents;

    return Column(
      children: [
        // Filter Controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSeries,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Series',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Series')),
                    ...series.map((s) => DropdownMenuItem(value: s, child: Text('$s'))),
                  ],
                  onChanged: (value) {
                    setState(() { selectedSeries = value; });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSection,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Section',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Sections')),
                    ...sections.map((s) => DropdownMenuItem(value: s, child: Text('Section $s'))),
                  ],
                  onChanged: (value) {
                    setState(() { selectedSection = value; });
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _loadAllStudents,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        // Students Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Total Students: ${students.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        // Students List
        Expanded(
          child: students.isEmpty
              ? const Center(
            child: Text(
              'No students found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
              : ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Text(
                      student['section'] ?? 'X',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    student['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Roll: ${student['roll']} | Series: 20${student['series']} | Section: ${student['section']}'),
                      if (student['email']?.isNotEmpty == true)
                        Text('Email: ${student['email']}'),
                      if (student['admissionRoll']?.isNotEmpty == true)
                        Text('Admission Roll: ${student['admissionRoll']}'),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    onSelected: (value) {
                      if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Student'),
                            content: Text('Are you sure you want to delete ${student['name']}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteStudent(student['series'], student['id']);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseManagementTab extends StatefulWidget {
  @override
  State<_CourseManagementTab> createState() => _CourseManagementTabState();
}

class _CourseManagementTabState extends State<_CourseManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _theoryHoursController = TextEditingController();
  final TextEditingController _sessionalHoursController = TextEditingController();
  String _selectedAcademicYear = '1st_Year_Even';
  bool _isOptional = false;
  bool _isLoading = false;
  bool _isAddFormExpanded = false; // Add this state variable

  final List<String> _academicYears = [
    '1st_Year_Even',
    '1st_Year_Odd',
    '2nd_Year_Even',
    '2nd_Year_Odd',
    '3rd_Year_Even',
    '3rd_Year_Odd',
    '4th_Year_Even',
    '4th_Year_Odd',
  ];

  Future<void> _addCourse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(_selectedAcademicYear)
          .collection('course_list')
          .add({
        'code': _codeController.text.trim(),
        'title': _titleController.text.trim(),
        'credit': double.tryParse(_creditController.text.trim()) ?? 0.0,
        'theory_hours': double.tryParse(_theoryHoursController.text.trim()) ?? 0.0,
        'sessional_hours': double.tryParse(_sessionalHoursController.text.trim()) ?? 0.0,
        'optional': _isOptional,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course added successfully!')),
      );
      _codeController.clear();
      _titleController.clear();
      _creditController.clear();
      _theoryHoursController.clear();
      _sessionalHoursController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding course: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
          children: [
            // Minimized Add Course Section
            Card(
              child: ExpansionTile(
                initiallyExpanded: _isAddFormExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isAddFormExpanded = expanded;
                  });
                },
                leading: const Icon(Icons.add_circle_outline, color: Colors.green),
                title: const Text(
                  'Add New Course',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: _isAddFormExpanded
                    ? null
                    : const Text('Tap to add a new course to any academic year'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Academic Year and Course Code Row
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedAcademicYear,
                                  decoration: const InputDecoration(
                                    labelText: 'Academic Year',
                                    isDense: true,
                                  ),
                                  items: _academicYears.map((year) =>
                                      DropdownMenuItem(value: year, child: Text(year.replaceAll('_', ' ')))
                                  ).toList(),
                                  onChanged: (value) => setState(() => _selectedAcademicYear = value ?? '1st_Year_Even'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _codeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Course Code',
                                    isDense: true,
                                  ),
                                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Course Title
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Course Title',
                              isDense: true,
                            ),
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          // Credit Hours Row (Compact)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _creditController,
                                  decoration: const InputDecoration(
                                    labelText: 'Credits',
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _theoryHoursController,
                                  decoration: const InputDecoration(
                                    labelText: 'Theory Hrs',
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _sessionalHoursController,
                                  decoration: const InputDecoration(
                                    labelText: 'Lab Hrs',
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Optional Course Checkbox (Compact)
                          CheckboxListTile(
                            title: const Text('Optional Course'),
                            value: _isOptional,
                            onChanged: (value) => setState(() => _isOptional = value ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 12),
                          // Action Buttons
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _addCourse,
                                icon: _isLoading
                                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.add, size: 18),
                                label: Text(_isLoading ? 'Adding...' : 'Add Course'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () {
                                  _codeController.clear();
                                  _titleController.clear();
                                  _creditController.clear();
                                  _theoryHoursController.clear();
                                  _sessionalHoursController.clear();
                                  setState(() {
                                    _isOptional = false;
                                    _isAddFormExpanded = false;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )],
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.book, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(
                            'Courses by Academic Year',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _CoursesListView()),
                  ],
                ),
              ),
            ),
          ]
      )
    );
  }
}

class _CoursesListView extends StatelessWidget {
  final List<String> _academicYears = [
    '1st_Year_Odd',
    '1st_Year_Even',
    '2nd_Year_Odd',
    '2nd_Year_Even',
    '3rd_Year_Odd',
    '3rd_Year_Even',
    '4th_Year_Odd',
    '4th_Year_Even',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _academicYears.length,
      itemBuilder: (context, index) {
        final academicYear = _academicYears[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[800],
                child: Text(
                  academicYear.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                academicYear.replaceAll('_', ' '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: FutureBuilder<int>(
                future: _getCourseCount(academicYear),
                builder: (context, countSnapshot) {
                  if (countSnapshot.hasData) {
                    return Text('${countSnapshot.data} courses available');
                  }
                  return const Text('Loading course count...');
                },
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _AcademicYearCourses(academicYear: academicYear),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int> _getCourseCount(String academicYear) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(academicYear)
          .collection('course_list')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting course count for $academicYear: $e');
      return 0;
    }
  }
}

class _AcademicYearCourses extends StatelessWidget {
  final String academicYear;

  const _AcademicYearCourses({required this.academicYear});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(academicYear)
          .collection('course_list')
          .orderBy('code')
          .snapshots(),
      builder: (context, courseSnapshot) {
        if (courseSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (courseSnapshot.hasError) {
          print('Course fetch error for $academicYear: ${courseSnapshot.error}');
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  Text('Error: ${courseSnapshot.error}'),
                ],
              ),
            ),
          );
        }

        if (!courseSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No data available')),
          );
        }

        final courses = courseSnapshot.data!.docs;
        if (courses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No courses in this academic year',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: courses.map((course) {
            final data = course.data() as Map<String, dynamic>;
            final isLabCourse = (data['sessional_hours'] ?? 0.0) > 0.0;
            final courseType = isLabCourse ? 'Lab' : 'Theory';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLabCourse ? Colors.orange[800] : Colors.blue[800],
                  child: Text(
                    (data['code']?.toString().substring(0, 3) ?? 'COU').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                title: Text(
                  '${data['code'] ?? 'N/A'} - ${data['title'] ?? 'No Title'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Credit: ${data['credit'] ?? 0} | Type: $courseType'),
                    Text('Theory: ${data['theory_hours'] ?? 0}h | Lab: ${data['sessional_hours'] ?? 0}h per week'),
                    if (data['optional'] == true)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'OPTIONAL',
                          style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editCourse(context, academicYear, course.id, data),
                      tooltip: 'Edit Course',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteCourse(context, academicYear, course.id, data['code']?.toString()),
                      tooltip: 'Delete Course',
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _editCourse(BuildContext context, String academicYear, String courseId, Map<String, dynamic> data) {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }

  void _confirmDeleteCourse(BuildContext context, String academicYear, String courseId, String? courseCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete course "${courseCode ?? courseId}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCourse(context, academicYear, courseId);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCourse(BuildContext context, String academicYear, String courseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(academicYear)
          .collection('course_list')
          .doc(courseId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course deleted successfully')),
      );
    } catch (e) {
      print('Error deleting course: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting course: $e')),
      );
    }
  }
}

class _AssignmentManagementTab extends StatefulWidget {
  @override
  State<_AssignmentManagementTab> createState() => _AssignmentManagementTabState();
}

class _AssignmentManagementTabState extends State<_AssignmentManagementTab> {
  String? selectedCourse;
  String? selectedTeacherEmail;
  String? selectedSeries;
  String? selectedSemester;
  String? selectedAcademicYear;
  String? selectedSection;
  List<String> selectedCourses = [];
  bool _isLoading = false;

  final List<String> _academicYears = [
    '1st_Year_Odd',
    '1st_Year_Even',
    '2nd_Year_Odd',
    '2nd_Year_Even',
    '3rd_Year_Odd',
    '3rd_Year_Even',
    '4th_Year_Odd',
    '4th_Year_Even',
  ];

  final List<String> _series = ['20', '21', '22', '23', '24'];
  final List<String> _sections = ['A', 'B', 'C'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Enhanced Course Assignment Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('Assign Courses to Students', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Academic Year and Section Selection
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Academic Year',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: selectedAcademicYear,
                            items: _academicYears.map((year) => DropdownMenuItem(
                              value: year,
                              child: Text(year.replaceAll('_', ' ')),
                            )).toList(),
                            onChanged: (value) => setState(() {
                              selectedAcademicYear = value;
                              selectedCourses.clear(); // Clear selected courses when academic year changes
                            }),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Section',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: selectedSection,
                            items: _sections.map((section) => DropdownMenuItem(
                              value: section,
                              child: Text('Section $section'),
                            )).toList(),
                            onChanged: (value) => setState(() => selectedSection = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Series Selection
                    Row(
                      children: [
                        Expanded(
                          child: FutureBuilder<List<String>>(
                            future: _fetchSeries(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const LinearProgressIndicator();
                              }
                              final series = snapshot.data ?? [];
                              return DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Series (e.g., 22)',
                                  border: OutlineInputBorder(),
                                ),
                                initialValue: selectedSeries,
                                items: _series.map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('$s Series'),
                                )).toList(),
                                onChanged: (value) => setState(() => selectedSeries = value),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Semester',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => selectedSemester = value,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Course Selection based on Academic Year
                    if (selectedAcademicYear != null) ...[
                      const Text('Select Courses to Assign:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FutureBuilder<List<Map<String, String>>>(
                            future: _fetchCoursesForAcademicYear(selectedAcademicYear!),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final courses = snapshot.data ?? [];
                              if (courses.isEmpty) {
                                return const Center(child: Text('No courses found for selected academic year'));
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: courses.length,
                                itemBuilder: (context, index) {
                                  final course = courses[index];
                                  final isSelected = selectedCourses.contains(course['id']);
                                  return CheckboxListTile(
                                    title: Text('${course['code']} - ${course['title']}'),
                                    subtitle: Text('Credit: ${course['credit']} | ${course['optional'] == 'true' ? 'Optional' : 'Mandatory'}'),
                                    value: isSelected,
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          selectedCourses.add(course['id']!);
                                        } else {
                                          selectedCourses.remove(course['id']);
                                        }
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _assignCoursesToStudents,
                          icon: _isLoading
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.assignment_turned_in),
                          label: Text(_isLoading ? 'Assigning...' : 'Assign Courses'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            selectedCourses.clear();
                            selectedSeries = null;
                            selectedSemester = null;
                            selectedSection = null;
                          }),
                          child: const Text('Clear Selection'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Teacher-Course Assignment Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_add, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Assign Teacher to Course', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Academic Year for Teacher Assignment
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Academic Year for Teacher Assignment',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: selectedAcademicYear,
                      items: _academicYears.map((year) => DropdownMenuItem(
                        value: year,
                        child: Text(year.replaceAll('_', ' ')),
                      )).toList(),
                      onChanged: (value) => setState(() {
                        selectedAcademicYear = value;
                        selectedCourse = null; // Reset selected course when academic year changes
                      }),
                    ),
                    const SizedBox(height: 16),
                    // Course Selection
                    FutureBuilder<List<Map<String, String>>>(
                      future: selectedAcademicYear != null ? _fetchCoursesForAcademicYear(selectedAcademicYear!) : Future.value([]),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        final courses = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Course',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: selectedCourse,
                          items: courses.map((course) => DropdownMenuItem(
                            value: course['id'],
                            child: Text(
                              '${course['code']} - ${course['title']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (value) => setState(() => selectedCourse = value),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Teacher Selection
                    FutureBuilder<List<Map<String, String>>>(
                      future: _fetchTeachers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        final teachers = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Select Teacher',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: selectedTeacherEmail,
                          items: teachers.map((teacher) => DropdownMenuItem(
                            value: teacher['email'],
                            child: Text(
                              '${teacher['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (value) => setState(() => selectedTeacherEmail = value),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _assignTeacherToCourse,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Assign Teacher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Current Assignments View
            SizedBox(
              height: 400,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.view_list, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text('Current Course Assignments', style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                    ),
                    Expanded(child: _CurrentAssignmentsView()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Enhanced method to fetch courses for a specific academic year
  Future<List<Map<String, String>>> _fetchCoursesForAcademicYear(String academicYear) async {
    List<Map<String, String>> courses = [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(academicYear)
          .collection('course_list')
          .orderBy('code')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final courseCode = data['code']?.toString() ?? '';
        final courseTitle = data['title']?.toString() ?? '';
        final credit = data['credit']?.toString() ?? '0';
        final optional = data['optional']?.toString() ?? 'false';

        if (courseCode.isNotEmpty) {
          courses.add({
            'id': doc.id,
            'code': courseCode,
            'title': courseTitle,
            'credit': credit,
            'optional': optional,
            'academicYear': academicYear,
          });
        }
      }
    } catch (e) {
      print('Error fetching courses for $academicYear: $e');
    }

    return courses;
  }

  Future<void> _assignCoursesToStudents() async {
    if (selectedAcademicYear == null || selectedSeries == null || selectedSemester == null ||
        selectedSection == null || selectedCourses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select at least one course')),
      );
      return;
    }

    setState(() { _isLoading = true; });
    try {
      // Create a comprehensive assignment document
      final assignmentId = '${selectedAcademicYear}_${selectedSeries}_${selectedSection}_sem${selectedSemester}';

      await FirebaseFirestore.instance
          .collection('courseAssignments')
          .doc(assignmentId)
          .set({
        'academicYear': selectedAcademicYear,
        'series': selectedSeries,
        'section': selectedSection,
        'semester': int.tryParse(selectedSemester!) ?? 1,
        'courseIds': selectedCourses,
        'assignedAt': FieldValue.serverTimestamp(),
        'assignedBy': 'admin',
      });

      // Also create individual student course assignments
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('student')
          .doc(selectedSection)
          .collection('section_students')
          .where('series', isEqualTo: selectedSeries)
          .get();

      for (var studentDoc in studentsSnapshot.docs) {
        final studentRoll = studentDoc.id;
        await FirebaseFirestore.instance
            .collection('studentCourseAssignments')
            .doc(studentRoll)
            .set({
          'roll': studentRoll,
          'series': selectedSeries,
          'section': selectedSection,
          'assignments': {
            assignmentId: {
              'academicYear': selectedAcademicYear,
              'semester': int.tryParse(selectedSemester!) ?? 1,
              'courseIds': selectedCourses,
              'assignedAt': FieldValue.serverTimestamp(),
            }
          }
        }, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully assigned ${selectedCourses.length} courses to ${studentsSnapshot.docs.length} students')),
      );

      setState(() {
        selectedCourses.clear();
        selectedSeries = null;
        selectedSemester = null;
        selectedSection = null;
      });
    } catch (e) {
      print('Error assigning courses: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning courses: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _assignTeacherToCourse() async {
    if (selectedAcademicYear == null || selectedCourse == null || selectedTeacherEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select academic year, course, and teacher'), backgroundColor: Colors.red,),
      );
      return;
    }

    setState(() { _isLoading = true; });
    try {
      final courseDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(selectedAcademicYear)
          .collection('course_list')
          .doc(selectedCourse)
          .get();

      if (!courseDoc.exists) {
        print('ERROR: Course document does not exist');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Selected course not found in database'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('Course document exists, proceeding with assignment...');

      await FirebaseFirestore.instance
          .collection('courses')
          .doc(selectedAcademicYear!)
          .collection('course_list')
          .doc(selectedCourse!)
          .update({
        'assignedTeacher': selectedTeacherEmail,
        'teacherAssignedAt': FieldValue.serverTimestamp(),
        'assignedBy': 'admin',
      });

      print('Teacher assignment successful!');
      print('Assigned: $selectedTeacherEmail to course: $selectedCourse');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Teacher assigned successfully!\n$selectedTeacherEmail → Course'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        selectedCourse = null;
        selectedTeacherEmail = null;
      });
    } catch (e) {
      print('Error assigning teacher: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning teacher: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<List<Map<String, String>>> _fetchTeachers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      Map<String, Map<String, String>> uniqueTeachers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final role = data['role']?.toString() ?? '';
        final name = data['name']?.toString().trim() ?? '';
        final email = data['email']?.toString().trim() ?? '';

        final teacherRoles = ['Course Teacher', 'Course Advisor', 'Department Head'];

        if (teacherRoles.contains(role) && name.isNotEmpty && email.isNotEmpty && email.contains('@')) {
          uniqueTeachers[email] = {
            'email': email,
            'name': name,
            'role': role,
          };
          print('Added teacher: $name ($role) - $email');
        }
      }

      final teachers = uniqueTeachers.values.toList();
      print('Total unique teachers found: ${teachers.length}');

      final emails = teachers.map((t) => t['email']).toList();
      print('Teacher emails: $emails');

      return teachers;
    } catch (e) {
      print('Error fetching teachers: $e');
      return [];
    }
  }

  Future<List<String>> _fetchSeries() async {
    List<String> series = [];
    try {
      final snapshot = await FirebaseFirestore.instance.collection('student').get();
      Set<String> uniqueSeries = {};

      for (var doc in snapshot.docs) {
        final sections = ['A', 'B', 'C'];
        for (String section in sections) {
          try {
            final studentsSnapshot = await FirebaseFirestore.instance
                .collection('student')
                .doc(section)
                .collection('section_students')
                .get();

            for (var studentDoc in studentsSnapshot.docs) {
              final data = studentDoc.data();
              final studentSeries = data['series']?.toString() ?? '';
              if (studentSeries.isNotEmpty) {
                uniqueSeries.add(studentSeries);
              }
            }
          } catch (e) {
            print('Error fetching students from section $section: $e');
          }
        }
      }

      series = uniqueSeries.toList()..sort();
    } catch (e) {
      print('Error fetching series: $e');
    }
    return series;
  }
}

class _CurrentAssignmentsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('courseAssignments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No course assignments found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final assignments = snapshot.data!.docs;
        return ListView.builder(
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final assignment = assignments[index];
            final data = assignment.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text(
                    data['section'] ?? 'X',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  '${data['academicYear']?.toString().replaceAll('_', ' ')} - Series ${data['series']} - Section ${data['section']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Semester: ${data['semester']} | Courses: ${(data['courseIds'] as List?)?.length ?? 0}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchCourseDetails(data['academicYear'], data['courseIds']),
                      builder: (context, courseSnapshot) {
                        if (courseSnapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        final courses = courseSnapshot.data ?? [];
                        if (courses.isEmpty) {
                          return const Text('No course details available');
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Assigned Courses:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...courses.map((course) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.book, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('${course['code']} - ${course['title']}'),
                                  ),
                                  Text(
                                    '${course['credit']} credits',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _deleteAssignment(context, assignment.id),
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('Delete Assignment'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCourseDetails(String? academicYear, List<dynamic>? courseIds) async {
    if (academicYear == null || courseIds == null) return [];

    List<Map<String, dynamic>> courses = [];
    try {
      for (String courseId in courseIds) {
        final doc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(academicYear)
            .collection('course_list')
            .doc(courseId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          courses.add({
            'code': data['code'] ?? 'N/A',
            'title': data['title'] ?? 'No Title',
            'credit': data['credit'] ?? 0,
          });
        }
      }
    } catch (e) {
      print('Error fetching course details: $e');
    }
    return courses;
  }

  void _deleteAssignment(BuildContext context, String assignmentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Assignment'),
          content: const Text('Are you sure you want to delete this course assignment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseFirestore.instance
                      .collection('courseAssignments')
                      .doc(assignmentId)
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assignment deleted successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting assignment: $e')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class _UserManagementTab extends StatefulWidget {
  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;

  final List<String> _roles = [
    'student',
    'teacher',
    'course_teacher',
    'course_advisor',
    'department_head',
    'admin',
  ];

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_emailController.text.trim())
          .set({
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User added successfully!')),
      );

      _emailController.clear();
      _nameController.clear();
      _passwordController.clear();
      setState(() => _selectedRole = 'student');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding user: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_add, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Add New User', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        if (!value!.contains('@')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value?.isEmpty == true) return 'Required';
                              if (value!.length < 6) return 'At least 6 characters';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.admin_panel_settings),
                            ),
                            items: _roles.map((role) => DropdownMenuItem(
                              value: role,
                              child: Text(role.replaceAll('_', ' ').toUpperCase()),
                            )).toList(),
                            onChanged: (value) => setState(() => _selectedRole = value ?? 'student'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _addUser,
                          icon: _isLoading
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.person_add),
                          label: Text(_isLoading ? 'Adding...' : 'Add User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            _emailController.clear();
                            _nameController.clear();
                            _passwordController.clear();
                            setState(() => _selectedRole = 'student');
                          },
                          child: const Text('Clear Form'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text('System Users', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                  ),
                  Expanded(child: _UsersListView()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No users found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final users = snapshot.data!.docs;

        // Group users by role
        final usersByRole = <String, List<QueryDocumentSnapshot>>{};
        for (var user in users) {
          final data = user.data() as Map<String, dynamic>;
          final role = data['role']?.toString() ?? 'unknown';
          usersByRole.putIfAbsent(role, () => []).add(user);
        }

        return ListView.builder(
          itemCount: usersByRole.keys.length,
          itemBuilder: (context, index) {
            final role = usersByRole.keys.elementAt(index);
            final roleUsers = usersByRole[role]!;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(role),
                  child: Text(
                    role.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  '${role.replaceAll('_', ' ').toUpperCase()} (${roleUsers.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: roleUsers.map((user) {
                  final data = user.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Text(
                        (data['name']?.toString().substring(0, 1) ?? 'U').toUpperCase(),
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    title: Text(data['name']?.toString() ?? 'Unknown'),
                    subtitle: Text(data['email']?.toString() ?? user.id),
                    trailing: PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editUser(context, user.id, data);
                        } else if (value == 'delete') {
                          _confirmDeleteUser(context, user.id, data['name']?.toString());
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red.shade800;
      case 'department_head':
        return Colors.purple.shade800;
      case 'course_advisor':
        return Colors.blue.shade800;
      case 'course_teacher':
      case 'teacher':
        return Colors.green.shade800;
      case 'student':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  void _editUser(BuildContext context, String userId, Map<String, dynamic> userData) {
    // TODO: Implement edit user functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit user functionality coming soon')),
    );
  }

  void _confirmDeleteUser(BuildContext context, String userId, String? userName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete user "${userName ?? userId}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser(context, userId);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _deleteUser(BuildContext context, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      print('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e')),
      );
    }
  }
}

class _ApprovalManagementTab extends StatefulWidget {
  @override
  State<_ApprovalManagementTab> createState() => _ApprovalManagementTabState();
}

class _ApprovalManagementTabState extends State<_ApprovalManagementTab> {
  List<Map<String, dynamic>> pendingApprovals = [];
  List<Map<String, dynamic>> approvedUsers = [];
  List<Map<String, dynamic>> rejectedUsers = [];
  bool isLoading = true;
  String selectedTab = 'pending'; // 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _loadAllApprovals();
  }

  Future<void> _loadAllApprovals() async {
    setState(() { isLoading = true; });
    try {
      // Load pending approvals (teacher roles with pending status)
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('approvalStatus', isEqualTo: 'pending')
          .get();

      // Load approved users (teacher roles with approved status)
      final approvedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('approvalStatus', isEqualTo: 'approved')
          .get();

      // Load rejected users (teacher roles with rejected status)
      final rejectedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('approvalStatus', isEqualTo: 'rejected')
          .get();

      List<Map<String, dynamic>> pending = [];
      List<Map<String, dynamic>> approved = [];
      List<Map<String, dynamic>> rejected = [];

      // Process pending approvals
      for (var doc in pendingSnapshot.docs) {
        final data = doc.data();
        final teacherRoles = ['Course Teacher', 'Course Advisor', 'Department Head'];
        if (teacherRoles.contains(data['role'])) {
          pending.add({
            'id': doc.id,
            'uid': data['uid'] ?? doc.id,
            'name': data['name'] ?? 'No Name',
            'email': data['email'] ?? 'No Email',
            'role': data['role'] ?? 'Unknown',
            'requestedAt': data['requestedAt']?.toDate() ?? DateTime.now(),
            'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          });
        }
      }

      // Process approved users
      for (var doc in approvedSnapshot.docs) {
        final data = doc.data();
        final teacherRoles = ['Course Teacher', 'Course Advisor', 'Department Head'];
        if (teacherRoles.contains(data['role']) && data['approvedBy'] != 'system') {
          approved.add({
            'id': doc.id,
            'uid': data['uid'] ?? doc.id,
            'name': data['name'] ?? 'No Name',
            'email': data['email'] ?? 'No Email',
            'role': data['role'] ?? 'Unknown',
            'approvedAt': data['approvedAt']?.toDate() ?? DateTime.now(),
            'approvedBy': data['approvedBy'] ?? 'Unknown',
          });
        }
      }

      // Process rejected users
      for (var doc in rejectedSnapshot.docs) {
        final data = doc.data();
        final teacherRoles = ['Course Teacher', 'Course Advisor', 'Department Head'];
        if (teacherRoles.contains(data['role'])) {
          rejected.add({
            'id': doc.id,
            'uid': data['uid'] ?? doc.id,
            'name': data['name'] ?? 'No Name',
            'email': data['email'] ?? 'No Email',
            'role': data['role'] ?? 'Unknown',
            'rejectedAt': data['rejectedAt']?.toDate() ?? DateTime.now(),
            'rejectedBy': data['rejectedBy'] ?? 'Unknown',
            'rejectionReason': data['rejectionReason'] ?? 'No reason provided',
          });
        }
      }

      setState(() {
        pendingApprovals = pending;
        approvedUsers = approved;
        rejectedUsers = rejected;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading approvals: $e');
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading approvals: $e')),
      );
    }
  }

  Future<void> _approveUser(String userId, String userEmail, String userName, String userRole) async {
    try {
      // Update user status to approved
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'approvalStatus': 'approved',
        'isActive': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin', // You could get current admin's info here
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName ($userRole) approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload approvals
      _loadAllApprovals();
    } catch (e) {
      print('Error approving user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving user: $e')),
      );
    }
  }

  Future<void> _rejectUser(String userId, String userName, String rejectionReason) async {
    try {
      // Update user status to rejected
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'approvalStatus': 'rejected',
        'isActive': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': 'admin',
        'rejectionReason': rejectionReason.isEmpty ? 'No reason provided' : rejectionReason,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName rejected successfully!'),
          backgroundColor: Colors.orange,
        ),
      );

      // Reload approvals
      _loadAllApprovals();
    } catch (e) {
      print('Error rejecting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting user: $e')),
      );
    }
  }

  void _showRejectDialog(String userId, String userName) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reject $userName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to reject this user?'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rejectUser(userId, userName, reasonController.text.trim());
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabButton(String tabName, String displayName, int count) {
    final isSelected = selectedTab == tabName;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => selectedTab = tabName),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blueGrey : Colors.grey.shade300,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          elevation: isSelected ? 4 : 1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayName),
            Text('($count)', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Course Teacher':
        return Colors.green.shade800;
      case 'Course Advisor':
        return Colors.blue.shade800;
      case 'Department Head':
        return Colors.purple.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Map<String, dynamic>> currentList;
    switch (selectedTab) {
      case 'approved':
        currentList = approvedUsers;
        break;
      case 'rejected':
        currentList = rejectedUsers;
        break;
      default:
        currentList = pendingApprovals;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.approval, color: Colors.blueGrey, size: 32),
              const SizedBox(width: 12),
              Text(
                'User Approval Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab Buttons
          Row(
            children: [
              _buildTabButton('pending', 'Pending', pendingApprovals.length),
              const SizedBox(width: 8),
              _buildTabButton('approved', 'Approved', approvedUsers.length),
              const SizedBox(width: 8),
              _buildTabButton('rejected', 'Rejected', rejectedUsers.length),
            ],
          ),
          const SizedBox(height: 16),

          // Refresh Button
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadAllApprovals,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const Spacer(),
              Text(
                'Total: ${currentList.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content List
          Expanded(
            child: currentList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selectedTab == 'pending' ? Icons.hourglass_empty :
                          selectedTab == 'approved' ? Icons.check_circle :
                          Icons.cancel,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedTab == 'pending' ? 'No pending approvals' :
                          selectedTab == 'approved' ? 'No approved users' :
                          'No rejected users',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: currentList.length,
                    itemBuilder: (context, index) {
                      final user = currentList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getRoleColor(user['role']),
                            child: Text(
                              user['name'].substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            user['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${user['email']}'),
                              Text('Role: ${user['role']}'),
                              if (selectedTab == 'pending')
                                Text('Requested: ${_formatDate(user['requestedAt'])}'),
                              if (selectedTab == 'approved')
                                Text('Approved: ${_formatDate(user['approvedAt'])} by ${user['approvedBy']}'),
                              if (selectedTab == 'rejected') ...[
                                Text('Rejected: ${_formatDate(user['rejectedAt'])} by ${user['rejectedBy']}'),
                                Text('Reason: ${user['rejectionReason']}',
                                     style: const TextStyle(color: Colors.red)),
                              ],
                            ],
                          ),
                          trailing: selectedTab == 'pending'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                    onPressed: () => _approveUser(
                                      user['uid'],
                                      user['email'],
                                      user['name'],
                                      user['role']
                                    ),
                                    tooltip: 'Approve',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () => _showRejectDialog(user['uid'], user['name']),
                                    tooltip: 'Reject',
                                  ),
                                ],
                              )
                            : selectedTab == 'rejected'
                              ? IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  onPressed: () => _confirmDeleteUser(user['uid'], user['name']),
                                  tooltip: 'Delete Permanently',
                                )
                              : null,
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _confirmDeleteUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete User Permanently'),
          content: Text('Are you sure you want to permanently delete "$userName"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .delete();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$userName deleted permanently')),
                  );
                  
                  _loadAllApprovals();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting user: $e')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
