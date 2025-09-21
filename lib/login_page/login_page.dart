import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../profile_page/course_teacher_dashboard_page.dart';
import '../profile_page/course_advisor_dashboard_page.dart';
import '../profile_page/department_head_dashboard_page.dart';
import '../profile_page/student_dashboard_page.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Loading state
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Sign in with email and password
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User user = userCredential.user!;

        // Fetch user role from Firestore first to check if it's the default admin
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        String role = userDoc.exists ? userDoc.get('role') : 'Course Teacher';
        bool isDefaultAdmin = userDoc.exists ? (userDoc.get('isDefaultAdmin') ?? false) : false;

        // Check if email is verified (skip verification check for default admin)
        if (!user.emailVerified && !isDefaultAdmin) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please verify your email to continue.")),
          );
          await FirebaseAuth.instance.signOut();
          return;
        }

        // If this is the default admin and email is not verified, skip verification requirement
        if (isDefaultAdmin && !user.emailVerified) {
          print("Default admin login - bypassing email verification requirement");
        }

        print("Login successful. Navigating to Dashboard...");

        // Role-based navigation
        Widget destination;
        if (role == 'Course Teacher') {
          destination = CourseTeacherDashboardPage(
            name: user.displayName ?? "User",
            email: user.email ?? "",
            role: role,
          );
        } else if (role == 'Course Advisor') {
          destination = CourseAdvisorDashboardPage(
            name: user.displayName ?? "User",
            email: user.email ?? "",
            role: role,
          );
        } else if (role == 'Department Head') {
          destination = DepartmentHeadDashboardPage(
            name: user.displayName ?? "User",
            email: user.email ?? "",
            role: role,
          );
        } else if (role == 'Student') {
          destination = StudentDashboardPage(
            name: user.displayName ?? "User",
            email: user.email ?? "",
            role: role,
          );
        } else {
          destination = CourseTeacherDashboardPage(
            name: user.displayName ?? "User",
            email: user.email ?? "",
            role: role,
          );
        }

        // Navigate to the selected page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => destination,
          ),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = "No user found with this email.";
            break;
          case 'wrong-password':
            errorMessage = "Incorrect password. Please try again.";
            break;
          case 'invalid-email':
            errorMessage = "The email address is not valid.";
            break;
          default:
            errorMessage = "An error occurred: ${e.message}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred: $e")),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      print("Form is invalid. Please check the fields.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 50),
                Center(
                  child: Text(
                    "Attendance System of \nRajshahi University of Engineering and Technology",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 50),
                Center(
                  child: Text(
                    "Greetings!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan[900], // Replaced hex code
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: Text(
                    "Please login to continue...",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blueGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 50),
                _buildEmailField(),
                SizedBox(height: 25),
                _buildPasswordField(),
                SizedBox(height: 25),
                _buildLoginButton(),
                SizedBox(height: 10),
                _buildForgotPasswordButton(),
                SizedBox(height: 10),
                _buildSignupButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Center(
      child: Material(
        elevation: 0.5,
        borderRadius: BorderRadius.circular(12.0),
        child: SizedBox(
          width: 500,
          child: TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.email_outlined,
                color: Colors.blueGrey,
              ),
              labelStyle: TextStyle(
                color: Colors.blueGrey,
                fontSize: 15,
              ),
              labelText: "Email",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Center(
      child: Material(
        elevation: 0.5,
        borderRadius: BorderRadius.circular(12.0),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 500,
              child: TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.blueGrey,
                  ),
                  labelStyle: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 15,
                  ),
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.blueGrey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 15.0),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          elevation: 2.0,
          fixedSize: Size(150, 50),
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login),
            SizedBox(width: 9),
            Text("Login"),
          ],
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
          );
        },
        child: Text(
          "Forgot Password?",
          style: TextStyle(
            fontSize: 16,
            color: Colors.blueGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSignupButton() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SignupPage()),
          );
        },
        child: Text(
          "Don't have an account? Sign up",
          style: TextStyle(
            fontSize: 16,
            color: Colors.blueGrey,
          ),
        ),
      ),
    );
  }
}