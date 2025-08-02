import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'schedule_page.dart';
import '../login_page/login_page.dart';
import 'payment_page.dart';

class StudentDashboardPage extends StatelessWidget {
  final String name;
  final String email;
  final String role;

  const StudentDashboardPage({
    super.key,
    required this.name,
    required this.email,
    required this.role,
  });

  void _logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final double gridMaxWidth = isSmallScreen ? double.infinity : 400;
    final double cardSize = isSmallScreen ? 120 : 100;
    final double iconSize = isSmallScreen ? 40 : 32;
    final double fontSize = isSmallScreen ? 18 : 16;
    final double cardPadding = isSmallScreen ? 12 : 8;
    final double spacing = isSmallScreen ? 16 : 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Dashboard"),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: "Logout",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Text(
                "Welcome, $name!",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Email: $email",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                "Student Actions",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: gridMaxWidth),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 1.0,
                  children: [
                    _buildDashboardCard(
                      icon: Icons.person,
                      title: "Profile",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfilePage(
                              name: name,
                              email: email,
                              password: "********",
                            ),
                          ),
                        );
                      },
                      cardSize: cardSize,
                      iconSize: iconSize,
                      fontSize: fontSize,
                      cardPadding: cardPadding,
                    ),
                    _buildDashboardCard(
                      icon: Icons.calendar_today,
                      title: "Schedule",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SchedulePage(),
                          ),
                        );
                      },
                      cardSize: cardSize,
                      iconSize: iconSize,
                      fontSize: fontSize,
                      cardPadding: cardPadding,
                    ),
                    _buildDashboardCard(
                      icon: Icons.assignment,
                      title: "View Attendance",
                      onTap: () {
                        // TODO: Implement view attendance page
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("View Attendance action")),
                        );
                      },
                      cardSize: cardSize,
                      iconSize: iconSize,
                      fontSize: fontSize,
                      cardPadding: cardPadding,
                    ),
                    _buildDashboardCard(
                      icon: Icons.book,
                      title: "Course Details",
                      onTap: () {
                        // TODO: Implement course details page
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Course Details action")),
                        );
                      },
                      cardSize: cardSize,
                      iconSize: iconSize,
                      fontSize: fontSize,
                      cardPadding: cardPadding,
                    ),
                    _buildDashboardCard(
                      icon: Icons.payment,
                      title: "Pay Fees",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentPage(),
                          ),
                        );
                      },
                      cardSize: cardSize,
                      iconSize: iconSize,
                      fontSize: fontSize,
                      cardPadding: cardPadding,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double cardSize,
    required double iconSize,
    required double fontSize,
    required double cardPadding,
  }) {
    return SizedBox(
      width: cardSize,
      height: cardSize,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(icon, size: iconSize, color: Colors.blueGrey),
                SizedBox(height: cardPadding / 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
