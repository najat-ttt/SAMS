import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Course {
  final String id;
  final String name;
  final String code;
  final int academicYear;
  final String semester;
  final String description;
  final DateTime createdAt;
  final String createdBy; // Admin who assigned this course

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.academicYear,
    required this.semester,
    this.description = '',
    required this.createdAt,
    required this.createdBy,
  });

  factory Course.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Course(
      id: doc.id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      academicYear: data['academicYear'] ?? 1,
      semester: data['semester'] ?? 'Fall',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'academicYear': academicYear,
      'semester': semester,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}

class CourseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference for courses
  static const String _coursesCollection = 'courses';
  static const String _userCoursesCollection = 'user_courses';

  /// Fetch courses assigned to a specific academic year
  static Future<List<Course>> getCoursesByAcademicYear(int academicYear, {String? semester}) async {
    try {
      Query query = _firestore
          .collection(_coursesCollection)
          .where('academicYear', isEqualTo: academicYear);

      if (semester != null) {
        query = query.where('semester', isEqualTo: semester);
      }

      QuerySnapshot snapshot = await query.orderBy('name').get();

      return snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching courses by academic year: $e');
      return [];
    }
  }

  /// Fetch courses for the current logged-in student
  static Future<List<Course>> getCoursesForCurrentStudent() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // First, get the student's academic year from their profile
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      int studentAcademicYear = userData['academicYear'] ?? 1;
      String currentSemester = userData['currentSemester'] ?? 'Fall';

      // Fetch courses for the student's academic year
      return await getCoursesByAcademicYear(studentAcademicYear, semester: currentSemester);
    } catch (e) {
      print('Error fetching courses for current student: $e');
      return [];
    }
  }

  /// Get all available courses (for admin use)
  static Future<List<Course>> getAllCourses() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_coursesCollection)
          .orderBy('academicYear')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching all courses: $e');
      return [];
    }
  }

  /// Add a new course (Admin only)
  static Future<String?> addCourse(Course course) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      DocumentReference docRef = await _firestore
          .collection(_coursesCollection)
          .add(course.toFirestore());

      return docRef.id;
    } catch (e) {
      print('Error adding course: $e');
      return null;
    }
  }

  /// Update an existing course (Admin only)
  static Future<bool> updateCourse(String courseId, Course course) async {
    try {
      await _firestore
          .collection(_coursesCollection)
          .doc(courseId)
          .update(course.toFirestore());

      return true;
    } catch (e) {
      print('Error updating course: $e');
      return false;
    }
  }

  /// Delete a course (Admin only)
  static Future<bool> deleteCourse(String courseId) async {
    try {
      await _firestore
          .collection(_coursesCollection)
          .doc(courseId)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting course: $e');
      return false;
    }
  }

  /// Get course names only (for compatibility with existing dropdown implementations)
  static Future<List<String>> getCourseNames({int? academicYear, String? semester}) async {
    try {
      List<Course> courses;

      if (academicYear != null) {
        courses = await getCoursesByAcademicYear(academicYear, semester: semester);
      } else {
        courses = await getCoursesForCurrentStudent();
      }

      return courses.map((course) => course.name).toList();
    } catch (e) {
      print('Error fetching course names: $e');
      return [];
    }
  }

  /// Get courses grouped by academic year
  static Future<Map<int, List<Course>>> getCoursesGroupedByYear() async {
    try {
      List<Course> allCourses = await getAllCourses();
      Map<int, List<Course>> groupedCourses = {};

      for (Course course in allCourses) {
        if (!groupedCourses.containsKey(course.academicYear)) {
          groupedCourses[course.academicYear] = [];
        }
        groupedCourses[course.academicYear]!.add(course);
      }

      return groupedCourses;
    } catch (e) {
      print('Error grouping courses by year: $e');
      return {};
    }
  }

  /// Stream courses for real-time updates
  static Stream<List<Course>> streamCoursesByAcademicYear(int academicYear, {String? semester}) {
    Query query = _firestore
        .collection(_coursesCollection)
        .where('academicYear', isEqualTo: academicYear);

    if (semester != null) {
      query = query.where('semester', isEqualTo: semester);
    }

    return query.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList();
    });
  }
}
