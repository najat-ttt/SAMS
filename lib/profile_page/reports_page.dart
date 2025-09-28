import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../services/course_service.dart';
import 'web_file_saver.dart'
    if (dart.library.io) 'web_file_saver_stub.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? selectedCourse;
  String? selectedSection;
  String? selectedSeries; // Add series selection
  bool isLoading = false;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();

  // Replace hardcoded courses with dynamic list from Firestore
  List<String> courses = [];
  bool isLoadingCourses = true;

  final List<String> sections = ["A", "B", "C"];
  final List<String> series = ["20", "21", "22", "23", "24"]; // Add series options

  List<Map<String, dynamic>> students = [];
  Map<String, Map<String, String>> attendanceData = {};
  List<String> datesList = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchCourses(); // Fetch courses from Firestore on init
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final double cardPadding = isSmallScreen ? 16 : 24;
    final double cardFontSize = isSmallScreen ? 16 : 18;
    final double buttonFontSize = isSmallScreen ? 16 : 15;
    final double buttonHeight = isSmallScreen ? 48 : 40;
    final double maxContentWidth = isSmallScreen ? double.infinity : 700;
    final double dropdownFontSize = isSmallScreen ? 16 : 15;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Reports"),
        backgroundColor: Colors.blueGrey,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Filter Section
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Generate Attendance Report",
                            style: TextStyle(
                              fontSize: cardFontSize + 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: selectedCourse,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: "Select Course",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  style: TextStyle(fontSize: dropdownFontSize, color: Colors.black),
                                  items: courses.map((course) {
                                    return DropdownMenuItem(
                                      value: course,
                                      child: Text(course, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedCourse = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: selectedSection,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: "Select Section",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  style: TextStyle(fontSize: dropdownFontSize, color: Colors.black),
                                  items: sections.map((section) {
                                    return DropdownMenuItem(
                                      value: section,
                                      child: Text("$section"),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedSection = value;
                                      _fetchStudents();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: selectedSeries,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: "Select Series",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  style: TextStyle(fontSize: dropdownFontSize, color: Colors.black),
                                  items: series.map((series) {
                                    return DropdownMenuItem(
                                      value: series,
                                      child: Text(series),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedSeries = value;
                                      _fetchStudents();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Start Date"),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _selectDate(context, true),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(DateFormat('dd-MM-yyyy').format(startDate)),
                                            const Icon(Icons.calendar_today),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("End Date"),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _selectDate(context, false),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(DateFormat('dd-MM-yyyy').format(endDate)),
                                            const Icon(Icons.calendar_today),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: buttonHeight + 4,
                                  child: ElevatedButton.icon(
                                    onPressed: isLoading ? null : _generateReport,
                                    icon: const Icon(Icons.refresh),
                                    label: Text("Generate Report", style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyan.shade500,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shadowColor: Color(0xFF90CAF9),
                                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 0 : 0),
                                      minimumSize: Size(double.infinity, buttonHeight + 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      textStyle: TextStyle(letterSpacing: 1.1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: buttonHeight + 4,
                                  child: ElevatedButton.icon(
                                    onPressed: (attendanceData.isEmpty || isLoading) ? null : _exportToExcel,
                                    icon: const Icon(Icons.table_chart),
                                    label: Text("Export to Excel", style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shadowColor: Colors.green.shade100,
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmallScreen ? 0 : 0), // Add horizontal padding
                                      minimumSize: Size(0, buttonHeight + 8), // Remove forced full width
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14), // Match other buttons
                                      ),
                                      textStyle: TextStyle(letterSpacing: 1.1),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: buttonHeight + 4,
                                  child: ElevatedButton.icon(
                                    onPressed: (attendanceData.isEmpty || isLoading) ? null : _exportToPdf,
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: Text("Export to PDF", style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shadowColor: Colors.red.shade100,
                                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 0 : 0),
                                      minimumSize: Size(double.infinity, buttonHeight + 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      textStyle: TextStyle(letterSpacing: 1.1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Report Preview
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (attendanceData.isEmpty)
                        ? const Center(
                      child: Text(
                        "No data to display.\nPlease select course, section and date range and generate report.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                        : Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Attendance Report: $selectedCourse - Section $selectedSection",
                              style: TextStyle(
                                fontSize: cardFontSize + 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Period: [${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}]",
                              style: TextStyle(
                                fontSize: cardFontSize - 2,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: _buildAttendanceTable(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          if (startDate.isAfter(endDate)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
          if (endDate.isBefore(startDate)) {
            startDate = endDate;
          }
        }
      });
    }
  }

  Future<void> _fetchCourses() async {
    setState(() {
      isLoadingCourses = true;
    });
    try {
      // Fetch courses from Firestore using CourseService
      final fetchedCourses = await CourseService.getCourseNames();
      setState(() {
        courses = fetchedCourses;
        isLoadingCourses = false;
      });
    } catch (e) {
      setState(() {
        courses = [];
        isLoadingCourses = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching courses: $e")),
      );
    }
  }

  Future<void> _fetchStudents() async {
    if (selectedSection == null || selectedSeries == null) {
      setState(() {
        students.clear();
      });
      return;
    }

    setState(() {
      isLoading = true;
      students.clear();
    });

    try {
      print('Fetching students from section-wise structure: students/$selectedSection/section_students for series: $selectedSeries');

      // Use the section-wise structure: students/{section}/section_students
      final querySnapshot = await _firestore
          .collection('student') // Main collection
          .doc(selectedSection) // Section document (A, B, C)
          .collection('section_students') // Students subcollection for this section
          .orderBy('roll')
          .get();

      print('Found ${querySnapshot.docs.length} students in section $selectedSection');

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          students = [];
        });

        // If no students in section-wise structure, try fallback to flat structure
        print('No students found in section-wise structure, trying flat structure...');
        await _fetchStudentsFromFlatStructure();
        return;
      }

      // Filter by series if the roll number pattern matches
      final filteredDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final rollStr = data['roll']?.toString() ?? '';
        return selectedSeries != null && rollStr.startsWith(selectedSeries!);
      }).toList();

      if (filteredDocs.isEmpty) {
        setState(() {
          students = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No students found for Series $selectedSeries, Section $selectedSection")),
        );
        return;
      }

      setState(() {
        students = filteredDocs.map((doc) {
          final data = doc.data();
          print('Student data: $data'); // Debug print
          return {
            "rollNo": data['roll'] ?? 0,
            "id": data['roll']?.toString() ?? '0',
            "name": data['name'] ?? data['studentName'] ?? 'Unknown', // Handle both field names
            "section": data['section'] ?? selectedSection,
          };
        }).toList();
      });

      print('Loaded ${students.length} students from section-wise structure');

    } catch (e) {
      print('Error fetching students from section-wise structure: $e'); // Debug print
      print('Trying fallback to flat structure...');
      await _fetchStudentsFromFlatStructure();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fallback method to fetch from flat structure for backward compatibility
  Future<void> _fetchStudentsFromFlatStructure() async {
    try {
      print('Fetching students from flat structure for section: $selectedSection and series: $selectedSeries');

      final querySnapshot = await _firestore
          .collection('student') // Flat collection
          .where('section', isEqualTo: selectedSection)
          .orderBy('roll')
          .get();

      print('Found ${querySnapshot.docs.length} students in flat structure');

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          students = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No students found for Section $selectedSection")),
        );
        return;
      }

      // Filter by series if the roll number pattern matches
      final filteredDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final rollStr = data['roll']?.toString() ?? '';
        return selectedSeries != null && rollStr.startsWith(selectedSeries!);
      }).toList();

      if (filteredDocs.isEmpty) {
        setState(() {
          students = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No students found for Series $selectedSeries, Section $selectedSection")),
        );
        return;
      }

      setState(() {
        students = filteredDocs.map((doc) {
          final data = doc.data();
          print('Student data from flat structure: $data');
          return {
            "rollNo": data['roll'] ?? 0,
            "id": data['roll']?.toString() ?? '0',
            "name": data['name'] ?? data['studentName'] ?? 'Unknown', // Handle both field names
            "section": data['section'] ?? selectedSection,
          };
        }).toList();
      });

      print('Loaded ${students.length} students from flat structure');

    } catch (e) {
      print('Error fetching students from flat structure: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching students: $e")),
      );
      setState(() {
        students = [];
      });
    }
  }

  Future<void> _generateReport() async {
    if (selectedCourse == null || selectedSection == null || students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select course and section first")),
      );
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        attendanceData.clear();
        datesList.clear();
      });
    }

    try {
      // Generate list of dates between start and end date
      List<DateTime> datesInRange = [];
      for (DateTime date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        datesInRange.add(date);
      }
      datesList = datesInRange.map((date) => DateFormat('dd-MM-yyyy').format(date)).toList();

      // Initialize attendance data structure
      for (var student in students) {
        attendanceData[student['id']] = {};
        for (var dateStr in datesList) {
          attendanceData[student['id']]![dateStr] = '-'; // Default to absent
        }
      }

      // Fetch all attendance records for the section and date range in parallel
      final List<Future<void>> fetchFutures = [];
      for (var dateStr in datesList) {
        fetchFutures.add(_firestore
            .collection('attendance_records')
            .doc(dateStr)
            .collection('sections')
            .doc(selectedSection)
            .collection('rolls')
            .get()
            .then((rollsSnapshot) async {
          if (rollsSnapshot.docs.isEmpty) return;
          final List<Future<void>> courseFutures = [];
          for (var rollDoc in rollsSnapshot.docs) {
            final rollNo = rollDoc.id;
            courseFutures.add(rollDoc.reference
                .collection('courses')
                .doc(selectedCourse)
                .get()
                .then((courseDoc) {
              if (courseDoc.exists) {
                String status = courseDoc.data()?['status'] ?? '-';
                if (attendanceData.containsKey(rollNo) && attendanceData[rollNo]!.containsKey(dateStr)) {
                  attendanceData[rollNo]![dateStr] = status == 'Present' ? 'P' : 'A';
                }
              }
            }));
          }
          await Future.wait(courseFutures);
        }));
      }
      await Future.wait(fetchFutures);

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating report: $e")),
        );
      }
    }
  }

  // Method to calculate attendance percentages
  Map<String, double> _calculateAttendancePercentages() {
    Map<String, double> percentages = {};

    for (var student in students) {
      String studentId = student['id'] ?? '';
      if (studentId.isEmpty) continue;

      int presentCount = 0;
      int totalSessions = 0;

      for (var dateStr in datesList) {
        String status = attendanceData[studentId]?[dateStr] ?? '-';
        if (status == 'P' || status == 'A') {
          totalSessions++;
          if (status == 'P') {
            presentCount++;
          }
        }
      }

      double percentage = totalSessions > 0 ? (presentCount / totalSessions) * 100 : 0.0;
      percentages[studentId] = percentage;
    }

    return percentages;
  }

  Widget _buildAttendanceTable() {
    final percentages = _calculateAttendancePercentages();

    return DataTable(
      columnSpacing: 12,
      headingRowColor: MaterialStateProperty.all(Colors.blueGrey[100]),
      border: TableBorder.all(color: Colors.grey.shade300),
      columns: [
        const DataColumn(
          label: Text(
            'Roll',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const DataColumn(
          label: Text(
            'Name',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...datesList.map(
              (dateStr) => DataColumn(
            label: SizedBox(
              width: 75,
              child: Text(
                dateStr.substring(5), // Show only MM-DD
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const DataColumn(
          label: Text(
            'Attendance %',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      rows: students.map((student) {
        final studentId = student['id'] ?? '';
        final percentage = percentages[studentId] ?? 0.0;
        return DataRow(
          cells: [
            DataCell(Text(studentId)),
            DataCell(Text(student['name'] ?? 'Unknown')),
            ...datesList.map(
                  (dateStr) {
                // Check if the studentId exists in attendanceData and if dateStr exists in the nested map
                final status = attendanceData[studentId]?[dateStr] ?? '-';
                return DataCell(
                  Center(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: (status == 'P')
                            ? Colors.green
                            : ((status == 'A')
                            ? Colors.red
                            : Colors.grey),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            DataCell(
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: percentage >= 50 ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Future<String?> _pickExportLocation(String fileName, String fileType) async {
    String? savePath;
    try {
      String? result = await FilePicker.platform.saveFile(
        dialogTitle: 'Select location to save $fileName',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [fileType],
      );
      if (result != null && result.isNotEmpty) {
        savePath = result;
      }
    } catch (e) {
      // ignore
    }
    return savePath;
  }

  Future<void> _exportToExcel() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }
      final excel_lib.Excel excel = excel_lib.Excel.createExcel();
      final excel_lib.Sheet sheet = excel['Attendance Report'];
      final percentages = _calculateAttendancePercentages();

      // Add header
      final headerCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      headerCell.value = excel_lib.TextCellValue('Attendance Report');

      final courseCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
      courseCell.value = excel_lib.TextCellValue('$selectedCourse - Section $selectedSection');

      final periodCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
      periodCell.value = excel_lib.TextCellValue('Period: ${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}');

      // Add table headers
      final rollHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4));
      rollHeaderCell.value = excel_lib.TextCellValue('Roll');

      final nameHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4));
      nameHeaderCell.value = excel_lib.TextCellValue('Name');

      // Add date headers
      for (int i = 0; i < datesList.length; i++) {
        final dateCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i + 2, rowIndex: 4));
        dateCell.value = excel_lib.TextCellValue(datesList[i]);
      }

      // Add percentage header
      final percentHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: datesList.length + 2, rowIndex: 4));
      percentHeaderCell.value = excel_lib.TextCellValue('Attendance %');

      // Add student data
      for (int i = 0; i < students.length; i++) {
        final student = students[i];

        final rollCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 5));
        rollCell.value = excel_lib.TextCellValue(student['id']);

        final nameCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 5));
        nameCell.value = excel_lib.TextCellValue(student['name']);

        for (int j = 0; j < datesList.length; j++) {
          final dateStr = datesList[j];
          final status = attendanceData[student['id']]![dateStr] ?? '-';

          final statusCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: j + 2, rowIndex: i + 5));
          statusCell.value = excel_lib.TextCellValue(status);
        }

        // Add percentage value
        final percentCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: datesList.length + 2, rowIndex: i + 5));
        final percentage = percentages[student['id']] ?? 0.0;
        percentCell.value = excel_lib.TextCellValue('${percentage.toStringAsFixed(1)}%');
      }

      // Save the file
      final fileName = 'attendance_report_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.xlsx';
      final fileBytes = excel.save();
      if (kIsWeb) {
        // Convert List<int> to Uint8List for web
        final bytes = Uint8List.fromList(fileBytes!);
        await saveFileWeb(bytes, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        if (mounted) {
          setState(() { isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Excel file downloaded!")),
          );
        }
        return;
      }
      // Desktop/Mobile: use file picker (desktop) or save to documents directory (mobile)
      String? path;
      if (Platform.isAndroid || Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        path = '${directory.path}/$fileName';
      } else {
        path = await _pickExportLocation(fileName, 'xlsx');
      }
      if (path == null) {
        if (mounted) setState(() { isLoading = false; });
        return;
      }
      final file = File(path);
      await file.writeAsBytes(fileBytes!);
      await OpenFile.open(path);
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Excel file saved to $path")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting to Excel: $e")),
        );
      }
    }
  }

  Future<void> _exportToPdf() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 8),
              pw.Text('$selectedCourse - Section $selectedSection', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Period: ${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
              pw.SizedBox(height: 20),
              _buildPdfTable(),
            ];
          },
        ),
      );

      // Save the file
      final fileName = 'attendance_report_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.pdf';
      final pdfBytes = await pdf.save();
      if (kIsWeb) {
        await saveFileWeb(pdfBytes, fileName, 'application/pdf');
        if (mounted) {
          setState(() { isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PDF file downloaded!")),
          );
        }
        return;
      }
      // Desktop/Mobile: use file picker (desktop) or save to documents directory (mobile)
      String? path;
      if (Platform.isAndroid || Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        path = '${directory.path}/$fileName';
      } else {
        path = await _pickExportLocation(fileName, 'pdf');
      }
      if (path == null) {
        if (mounted) setState(() { isLoading = false; });
        return;
      }
      final file = File(path);
      await file.writeAsBytes(pdfBytes);
      await OpenFile.open(path);

      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Pdf file saved to $path")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting to Pdf: $e")),
        );
      }
    }
  }

  pw.Table _buildPdfTable() {
    final percentages = _calculateAttendancePercentages();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Roll', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
            ),
            ...datesList.map(
                  (dateStr) => pw.Padding(
                padding: const pw.EdgeInsets.all(2),
                child: pw.Text(dateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6)),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Attendance %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
            ),
          ],
        ),
        // Data rows
        ...students.map(
                (student) {
              final percentage = percentages[student['id']] ?? 0.0;
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      student['id'].toString().length > 4
                        ? student['id'].toString().substring(0, 4) + '\n' + student['id'].toString().substring(4)
                        : student['id'].toString(),
                      style: pw.TextStyle(fontSize: 6),
                      softWrap: true,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(student['name'], style: pw.TextStyle(fontSize: 6)),
                  ),
                  ...datesList.map(
                        (dateStr) {
                      final status = attendanceData[student['id']]![dateStr] ?? '-';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(1),
                        child: pw.Center(
                          child: pw.Text(
                            status,
                            style: pw.TextStyle(
                              fontSize: 6,
                              color: status == 'P'
                                  ? PdfColors.green
                                  : (status == 'A' ? PdfColors.red : PdfColors.grey),
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: pw.TextStyle(
                        fontSize: 6,
                        color: percentage >= 75 ? PdfColors.green : PdfColors.red,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }),
      ],
    );
  }
}
