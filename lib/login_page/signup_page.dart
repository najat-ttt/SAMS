import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../profile_page/course_teacher_dashboard_page.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false; // Loading state
  String _selectedRole = 'Course Teacher'; // Default role

  final List<String> _roles = [
    'Course Teacher',
    'Course Advisor',
    'Department Head',
    'Student',
  ]; // Available roles

  final _formKey = GlobalKey<FormState>(); // Form key for validation
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          child: Form(
            key: _formKey, // Add Form widget
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40),
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
                SizedBox(height: 40),
                Center(
                  child: Text(
                    "Create an Account",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan[900],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 10),
                Center(
                  child: Text(
                    "Sign up to get started...",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blueGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 40),
                _buildTextField(
                    "Full Name", Icons.person_outline_rounded, false, nameController, null),
                SizedBox(height: 15),
                _buildTextField(
                    "Email", Icons.email_outlined, false, emailController, null),
                SizedBox(height: 15),
                _buildTextField(
                    "Password", Icons.lock_outline_rounded, true, passwordController, () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                }),
                SizedBox(height: 15),
                _buildTextField("Confirm Password", Icons.lock_outline_rounded, true,
                    confirmPasswordController, () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    }),
                SizedBox(height: 15),
                _buildRoleDropdown(), // Role selection dropdown
                SizedBox(height: 35),
                Center(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    // Disable button when loading
                    style: ElevatedButton.styleFrom(
                      elevation: 2.0,
                      fixedSize: Size(150, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                        color: Colors.white) // Show loading indicator
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_outlined),
                        SizedBox(width: 9),
                        Text("Sign Up"),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text(
                      "Already have an account? Login",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String labelText, IconData icon, bool isPassword,
      TextEditingController controller, VoidCallback? toggleVisibility) {
    return Center(
      child: Material(
        elevation: 0.5,
        borderRadius: BorderRadius.circular(12.0),
        child: SizedBox(
          width: 500,
          child: TextFormField(
            controller: controller,
            obscureText: isPassword &&
                !(toggleVisibility == null
                    ? (_isPasswordVisible || _isConfirmPasswordVisible)
                    : (labelText == "Password"
                    ? _isPasswordVisible
                    : _isConfirmPasswordVisible)),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Colors.blueGrey,
              ),
              labelStyle: TextStyle(
                color: Colors.blueGrey,
                fontSize: 15,
              ),
              labelText: labelText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
              suffixIcon: toggleVisibility != null
                  ? IconButton(
                icon: Icon(
                  isPassword
                      ? (labelText == "Password"
                      ? (_isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined)
                      : (_isConfirmPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined))
                      : null,
                  color: Colors.blueGrey,
                ),
                onPressed: toggleVisibility,
              )
                  : null,
              contentPadding: EdgeInsets.symmetric(vertical: 15.0),
            ),
            validator: (value) {
              if (labelText == "Confirm Password" && (value == null || value.isEmpty)) {
                return 'Please $labelText';
              }
              if (value == null || value.isEmpty) {
                return 'Please enter $labelText';
              }
              if (labelText == "Email" &&
                  !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                return 'Please enter a valid email';
              }
              if (labelText == "Password" && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Center(
      child: Material(
        elevation: 0.5,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: 500,
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.blueGrey),
          ),
          child: DropdownButton<String>(
            value: _selectedRole,
            onChanged: (String? newValue) {
              setState(() {
                _selectedRole = newValue!;
              });
            },
            items: _roles.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: TextStyle(
                    color: _getRoleColor(value), // Set color based on role
                    fontSize: 16,
                  ),
                ),
              );
            }).toList(),
            isExpanded: true,
            underline: SizedBox(), // Remove the default underline
          ),
        ),
      ),
    );
  }

  // Helper function to assign colors based on role
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Course Teacher':
        return Colors.blueGrey; // Blue for Course Teacher
      case 'Course Advisor':
        return Colors.blueGrey; // Purple for Course Advisor
      case 'Department Head':
        return Colors.blueGrey; // Green for Department Head
      case 'Student':
        return Colors.blueGrey; // Orange for Student
      default:
        return Colors.black; // Default color
    }
  }

  // Sign Up method using Firebase Authentication
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (passwordController.text != confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Passwords do not match")),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // Create user with email and password
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        User user = userCredential.user!;

        // Update the user's display name
        await user.updateDisplayName(nameController.text.trim());

        // Save user info and role to Firestore
        final teacherRoles = ['Course Teacher', 'Course Advisor', 'Department Head'];
        final needsApproval = teacherRoles.contains(_selectedRole);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'role': _selectedRole,
          'approvalStatus': needsApproval ? 'pending' : 'approved',
          'requestedAt': needsApproval ? FieldValue.serverTimestamp() : null,
          'approvedAt': needsApproval ? null : FieldValue.serverTimestamp(),
          'approvedBy': needsApproval ? null : 'system',
          'isActive': !needsApproval, // Students are active immediately, teachers need approval
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send email verification
        await user.sendEmailVerification();

        // Show different messages based on whether approval is needed
        String message = needsApproval
          ? "Account created successfully! Your ${_selectedRole} account is pending admin approval. You'll receive an email once approved."
          : "Verification email sent! Please check your inbox and verify your email to continue.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: 5),
            backgroundColor: needsApproval ? Colors.orange : Colors.green,
          ),
        );

        // Redirect to LoginPage after signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );

        print("Signup successful, verification email sent, redirecting to login...");
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = "The email address is already in use by another account.";
            break;
          case 'invalid-email':
            errorMessage = "The email address is not valid.";
            break;
          case 'weak-password':
            errorMessage = "The password is too weak.";
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
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}