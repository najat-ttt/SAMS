import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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
        ],
      ),
    );
  }
}

class _StudentManagementTab extends StatefulWidget {
  @override
  State<_StudentManagementTab> createState() => _StudentManagementTabState();
}

class _StudentManagementTabState extends State<_StudentManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _seriesController = TextEditingController();
  String _selectedSection = 'A';
  bool _isLoading = false;

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      final seriesDoc = 'series-${_seriesController.text.trim()}';
      final roll = int.tryParse(_rollController.text.trim()) ?? 0;
      await FirebaseFirestore.instance
          .collection('student')
          .doc(seriesDoc)
          .collection('students')
          .doc(roll.toString())
          .set({
        'roll': roll,
        'name': _nameController.text.trim(),
        'section': _selectedSection,
        'series': _seriesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully!')),
      );
      _nameController.clear();
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
        allowedExtensions: ['xlsx']
      );
      if (result == null || result.files.isEmpty) {
        setState(() { _isLoading = false; });
        return;
      }

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        setState(() { _isLoading = false; });
        return;
      }

      final excel = Excel.decodeBytes(fileBytes);
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        setState(() { _isLoading = false; });
        return;
      }

      // Find column indexes
      final header = sheet.rows.first.map((cell) {
        if (cell == null || cell.value == null) return '';
        return cell.value.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
      }).toList();

      int nameIdx = -1, rollIdx = -1, seriesIdx = -1, sectionIdx = -1;
      for (int i = 0; i < header.length; i++) {
        if (header[i].contains('name')) nameIdx = i;
        if (header[i].contains('roll')) rollIdx = i;
        if (header[i].contains('series')) seriesIdx = i;
        if (header[i].contains('section')) sectionIdx = i;
      }

      if (nameIdx == -1 || rollIdx == -1 || seriesIdx == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel must have Name, Roll, and Series columns')),
        );
        setState(() { _isLoading = false; });
        return;
      }

      // Upload each row
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final name = row.length > nameIdx ? row[nameIdx]?.value?.toString()?.trim() ?? '' : '';
        final rollStr = row.length > rollIdx ? row[rollIdx]?.value?.toString()?.trim() ?? '' : '';
        final series = row.length > seriesIdx ? row[seriesIdx]?.value?.toString()?.trim() ?? '' : '';
        final section = row.length > sectionIdx ? row[sectionIdx]?.value?.toString()?.trim() ?? 'A' : 'A';

        if (name.isEmpty || rollStr.isEmpty || series.isEmpty) continue;

        final roll = int.tryParse(rollStr) ?? 0;
        final seriesDoc = 'series-$series';

        await FirebaseFirestore.instance
            .collection('student')
            .doc(seriesDoc)
            .collection('students')
            .doc(roll.toString())
            .set({
          'roll': roll,
          'name': name,
          'section': section,
          'series': series,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Students imported successfully!')),
      );
    } catch (e) {
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
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Student Name'),
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _rollController,
                            decoration: const InputDecoration(labelText: 'Roll Number'),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
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
                            value: _selectedSection,
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

class _StudentsListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('student').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final seriesDocs = snapshot.data?.docs ?? [];
        if (seriesDocs.isEmpty) {
          return const Center(child: Text('No students found'));
        }

        return ListView.builder(
          itemCount: seriesDocs.length,
          itemBuilder: (context, index) {
            final seriesDoc = seriesDocs[index];
            final seriesId = seriesDoc.id;

            return ExpansionTile(
              title: Text('Series: ${seriesId.replaceFirst('series-', '')}'),
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('student')
                      .doc(seriesId)
                      .collection('students')
                      .orderBy('roll')
                      .snapshots(),
                  builder: (context, studentSnapshot) {
                    if (studentSnapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(title: Text('Loading...'));
                    }

                    final students = studentSnapshot.data?.docs ?? [];
                    if (students.isEmpty) {
                      return const ListTile(title: Text('No students in this series'));
                    }

                    return Column(
                      children: students.map((student) {
                        final data = student.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(child: Text('${data['roll']}')),
                          title: Text(data['name'] ?? ''),
                          subtitle: Text('Section: ${data['section'] ?? 'N/A'}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteStudent(seriesId, student.id),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteStudent(String seriesId, String studentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('student')
          .doc(seriesId)
          .collection('students')
          .doc(studentId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting student: $e');
    }
  }
}

class _CourseManagementTab extends StatefulWidget {
  @override
  State<_CourseManagementTab> createState() => _CourseManagementTabState();
}

class _CourseManagementTabState extends State<_CourseManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _semesterController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addCourse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      await FirebaseFirestore.instance.collection('courses').doc(_codeController.text.trim()).set({
        'code': _codeController.text.trim(),
        'name': _nameController.text.trim(),
        'credit': double.tryParse(_creditController.text.trim()) ?? 0.0,
        'semester': int.tryParse(_semesterController.text.trim()) ?? 1,
        'department': _departmentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course added successfully!')),
      );
      _codeController.clear();
      _nameController.clear();
      _creditController.clear();
      _semesterController.clear();
      _departmentController.clear();
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Course', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            decoration: const InputDecoration(labelText: 'Course Code'),
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Course Name'),
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _creditController,
                            decoration: const InputDecoration(labelText: 'Credit Hours'),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _semesterController,
                            decoration: const InputDecoration(labelText: 'Semester'),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _departmentController,
                            decoration: const InputDecoration(labelText: 'Department'),
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addCourse,
                      child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                        : const Text('Add Course'),
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
                    child: Text('Courses List', style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Expanded(child: _CoursesListView()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('courses').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final courses = snapshot.data?.docs ?? [];
        if (courses.isEmpty) {
          return const Center(child: Text('No courses found'));
        }

        return ListView.builder(
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            final data = course.data() as Map<String, dynamic>;

            return ListTile(
              leading: CircleAvatar(child: Text(data['code']?.substring(0, 2) ?? 'C')),
              title: Text('${data['code']} - ${data['name']}'),
              subtitle: Text('Credit: ${data['credit']} | Semester: ${data['semester']} | Dept: ${data['department']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data['teacher'] != null)
                    Chip(
                      label: Text('Teacher: ${data['teacher']}'),
                      backgroundColor: Colors.green.shade100,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCourse(course.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteCourse(String courseId) async {
    try {
      await FirebaseFirestore.instance.collection('courses').doc(courseId).delete();
    } catch (e) {
      debugPrint('Error deleting course: $e');
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
  List<String> selectedCourses = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Teacher-Course Assignment Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign Teacher to Course', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<List<Map<String, String>>>(
                          future: _fetchCourses(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            final courses = snapshot.data ?? [];
                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Select Course'),
                              value: selectedCourse,
                              items: courses.map((course) => DropdownMenuItem(
                                value: course['code'],
                                child: Text('${course['code']} - ${course['name']}'),
                              )).toList(),
                              onChanged: (value) => setState(() => selectedCourse = value),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FutureBuilder<List<Map<String, String>>>(
                          future: _fetchTeachers(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            final teachers = snapshot.data ?? [];
                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Select Teacher'),
                              value: selectedTeacherEmail,
                              items: teachers.map((teacher) => DropdownMenuItem(
                                value: teacher['email'],
                                child: Text('${teacher['name']} (${teacher['email']})'),
                              )).toList(),
                              onChanged: (value) => setState(() => selectedTeacherEmail = value),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _assignTeacherToCourse,
                    child: const Text('Assign Teacher'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Student-Course Assignment Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign Courses to Students', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
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
                              decoration: const InputDecoration(labelText: 'Select Series'),
                              value: selectedSeries,
                              items: series.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              )).toList(),
                              onChanged: (value) => setState(() => selectedSeries = value),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: 'Semester'),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => selectedSemester = value,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, String>>>(
                    future: _fetchCourses(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      final courses = snapshot.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Courses:'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: courses.map((course) {
                              final isSelected = selectedCourses.contains(course['code']);
                              return FilterChip(
                                label: Text('${course['code']} - ${course['name']}'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedCourses.add(course['code']!);
                                    } else {
                                      selectedCourses.remove(course['code']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _assignCoursesToStudents,
                    child: const Text('Assign Courses to Series'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, String>>> _fetchCourses() async {
    final snapshot = await FirebaseFirestore.instance.collection('courses').get();
    return snapshot.docs.map((doc) => {
      'code': doc['code']?.toString() ?? '',
      'name': doc['name']?.toString() ?? doc['code']?.toString() ?? '',
    }).where((course) => course['code']!.isNotEmpty).toList();
  }

  Future<List<Map<String, String>>> _fetchTeachers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    List<Map<String, String>> teachers = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final role = data['role']?.toString().trim().toLowerCase();
      final email = data['email']?.toString() ?? '';
      final name = data['name']?.toString() ?? email;
      if (role == 'course teacher' && email.isNotEmpty) {
        teachers.add({'email': email, 'name': name});
      }
    }
    return teachers;
  }

  Future<List<String>> _fetchSeries() async {
    final snapshot = await FirebaseFirestore.instance.collection('student').get();
    return snapshot.docs.map((doc) => doc.id.replaceFirst('series-', '')).toList();
  }

  Future<void> _assignTeacherToCourse() async {
    if (selectedCourse == null || selectedTeacherEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both course and teacher')),
      );
      return;
    }

    setState(() { _isLoading = true; });
    try {
      await FirebaseFirestore.instance.collection('courses').doc(selectedCourse).update({
        'teacher': selectedTeacherEmail,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher assigned successfully!')),
      );
      setState(() {
        selectedCourse = null;
        selectedTeacherEmail = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning teacher: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _assignCoursesToStudents() async {
    if (selectedSeries == null || selectedSemester == null || selectedCourses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select series, semester, and at least one course')),
      );
      return;
    }

    setState(() { _isLoading = true; });
    try {
      final seriesDoc = 'series-$selectedSeries';
      await FirebaseFirestore.instance
          .collection('courseAssignments')
          .doc('${seriesDoc}_semester_$selectedSemester')
          .set({
        'series': selectedSeries,
        'semester': int.tryParse(selectedSemester!) ?? 1,
        'courses': selectedCourses,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Courses assigned to students successfully!')),
      );
      setState(() {
        selectedSeries = null;
        selectedSemester = null;
        selectedCourses.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning courses: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }
}

class _UserManagementTab extends StatefulWidget {
  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'Student';
  bool _isLoading = false;

  final List<String> _roles = [
    'Student',
    'Course Teacher',
    'Course Advisor',
    'Department Head',
    'Admin'
  ];

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      await FirebaseFirestore.instance.collection('users').doc(_emailController.text.trim()).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'password': _passwordController.text.trim(), // In a real app, hash this
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User added successfully!')),
      );
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
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
                    Text('Add User', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Full Name'),
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(labelText: 'Email'),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                            validator: (value) => value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(labelText: 'Role'),
                            items: _roles.map((role) =>
                              DropdownMenuItem(value: role, child: Text(role))
                            ).toList(),
                            onChanged: (value) => setState(() => _selectedRole = value ?? 'Student'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addUser,
                      child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                        : const Text('Add User'),
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
                    child: Text('Users List', style: Theme.of(context).textTheme.headlineSmall),
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
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data?.docs ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final data = user.data() as Map<String, dynamic>;

            return ListTile(
              leading: CircleAvatar(
                child: Text((data['name'] ?? '').toString().substring(0, 1).toUpperCase()),
              ),
              title: Text(data['name'] ?? ''),
              subtitle: Text('${data['email']} • Role: ${data['role']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteUser(user.id),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    } catch (e) {
      debugPrint('Error deleting user: $e');
    }
  }
}

