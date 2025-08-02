import 'package:flutter/material.dart';

class PaymentPage extends StatefulWidget {
  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String? selectedFeeType;

  final List<String> feeTypes = [
    'Course Registration',
    'Exam Fee',
    'Hall Fee',
    'Annual Dept Fee',
    'Insurance',
    'Certificate',
    'Hall Coupon',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pay Fees')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Fee Type:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ...feeTypes.map((type) => ListTile(
                  title: Text(type),
                  leading: Radio<String>(
                    value: type,
                    groupValue: selectedFeeType,
                    onChanged: (value) {
                      setState(() {
                        selectedFeeType = value;
                      });
                    },
                  ),
                  onTap: () {
                    setState(() {
                      selectedFeeType = type;
                    });
                  },
                )),
            SizedBox(height: 24),
            if (selectedFeeType != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeeFormPage(feeType: selectedFeeType!),
                    ),
                  );
                },
                child: Text('Next'),
              ),
          ],
        ),
      ),
    );
  }
}

class FeeFormPage extends StatelessWidget {
  final String feeType;

  FeeFormPage({required this.feeType});

  @override
  Widget build(BuildContext context) {
    Widget formWidget;
    switch (feeType) {
      case 'Course Registration':
        formWidget = CourseRegistrationForm();
        break;
      case 'Exam Fee':
        formWidget = ExamFeeForm();
        break;
      case 'Hall Fee':
        formWidget = HallFeeForm();
        break;
      case 'Annual Dept Fee':
        formWidget = AnnualDeptFeeForm();
        break;
      case 'Insurance':
        formWidget = InsuranceFeeForm();
        break;
      case 'Certificate':
        formWidget = CertificateFeeForm();
        break;
      case 'Hall Coupon':
        formWidget = HallCouponFeeForm();
        break;
      default:
        formWidget = Center(child: Text('Unknown Fee Type'));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Fee Form - $feeType')),
      body: formWidget,
    );
  }
}

// Detailed forms for each fee type
class CourseRegistrationForm extends StatefulWidget {
  @override
  _CourseRegistrationFormState createState() => _CourseRegistrationFormState();
}

class _CourseRegistrationFormState extends State<CourseRegistrationForm> {
  String? dept;
  String? roll;
  String? studentType;
  String? examType;
  String? semester;
  List<String> selectedCourses = [];

  final List<String> depts = ['CSE', 'EEE', 'ME', 'CE'];
  final List<String> studentTypes = ['Regular', 'Backlog', 'Short'];
  final List<String> examTypes = ['Mid', 'Final'];
  final List<String> semesters = ['1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th'];
  final Map<String, List<String>> coursesByType = {
    'Regular': ['Math101', 'CSE101', 'EEE101'],
    'Backlog': ['Math101', 'CSE101'],
    'Short': ['CSE101'],
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Department'),
            value: dept,
            items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => dept = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Roll'),
            onChanged: (v) => setState(() => roll = v),
          ),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Student Type'),
            value: studentType,
            items: studentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() { studentType = v; selectedCourses.clear(); }),
          ),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Exam Type'),
            value: examType,
            items: examTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => examType = v),
          ),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Semester'),
            value: semester,
            items: semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => semester = v),
          ),
          if (studentType != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                Text('Select Courses:'),
                ...coursesByType[studentType]!.map((course) => CheckboxListTile(
                  title: Text(course),
                  value: selectedCourses.contains(course),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selectedCourses.add(course);
                      } else {
                        selectedCourses.remove(course);
                      }
                    });
                  },
                )),
              ],
            ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Validation and next step
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Course Registration Submitted')),
              );
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class ExamFeeForm extends StatefulWidget {
  @override
  _ExamFeeFormState createState() => _ExamFeeFormState();
}

class _ExamFeeFormState extends State<ExamFeeForm> {
  String? semester;
  String? dept;
  String? name;
  String? fatherName;
  String? examType;
  List<String> selectedCourses = [];

  final List<String> depts = ['CSE', 'EEE', 'ME', 'CE'];
  final List<String> examTypes = ['Mid', 'Final'];
  final List<String> semesters = ['1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th'];
  final List<String> courses = ['Math101', 'CSE101', 'EEE101'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Semester'),
            value: semester,
            items: semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => semester = v),
          ),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Department'),
            value: dept,
            items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => dept = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Name'),
            onChanged: (v) => setState(() => name = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: "Father's Name"),
            onChanged: (v) => setState(() => fatherName = v),
          ),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Exam Type'),
            value: examType,
            items: examTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => examType = v),
          ),
          SizedBox(height: 16),
          Text('Select Courses:'),
          ...courses.map((course) => CheckboxListTile(
            title: Text(course),
            value: selectedCourses.contains(course),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  selectedCourses.add(course);
                } else {
                  selectedCourses.remove(course);
                }
              });
            },
          )),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Validation and next step
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exam Fee Submitted')),
              );
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class HallFeeForm extends StatefulWidget {
  @override
  _HallFeeFormState createState() => _HallFeeFormState();
}

class _HallFeeFormState extends State<HallFeeForm> {
  String? hall;
  String? room;
  String? roll;
  final List<String> halls = ['Ahsanullah', 'Shahid Smrity', 'Bangabandhu'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Hall'),
            value: hall,
            items: halls.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
            onChanged: (v) => setState(() => hall = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Room'),
            onChanged: (v) => setState(() => room = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Roll'),
            onChanged: (v) => setState(() => roll = v),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Validation and next step
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Hall Fee Submitted')),
              );
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class AnnualDeptFeeForm extends StatefulWidget {
  @override
  _AnnualDeptFeeFormState createState() => _AnnualDeptFeeFormState();
}

class _AnnualDeptFeeFormState extends State<AnnualDeptFeeForm> {
  String? dept;
  String? roll;
  final List<String> depts = ['CSE', 'EEE', 'ME', 'CE'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Department'),
            value: dept,
            items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => dept = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Roll'),
            onChanged: (v) => setState(() => roll = v),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Validation and next step
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Annual Dept Fee Submitted')),
              );
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class InsuranceFeeForm extends StatefulWidget {
  @override
  _InsuranceFeeFormState createState() => _InsuranceFeeFormState();
}

class _InsuranceFeeFormState extends State<InsuranceFeeForm> {
  String? dept;
  String? roll;
  final List<String> depts = ['CSE', 'EEE', 'ME', 'CE'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Department'),
            value: dept,
            items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => dept = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Roll'),
            onChanged: (v) => setState(() => roll = v),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Validation and next step
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Insurance Fee Submitted')),
              );
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class CertificateFeeForm extends StatefulWidget {
  @override
  _CertificateFeeFormState createState() => _CertificateFeeFormState();
}

class _CertificateFeeFormState extends State<CertificateFeeForm> {
  String? series;
  String? dept;
  String? roll;
  final List<String> depts = ['CSE', 'EEE', 'ME', 'CE'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            decoration: InputDecoration(labelText: 'Series'),
            onChanged: (v) => setState(() => series = v),
          ),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Department'),
            value: dept,
            items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => dept = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Roll'),
            onChanged: (v) => setState(() => roll = v),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Validation and next step
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Certificate Fee Submitted')),
              );
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class HallCouponFeeForm extends StatefulWidget {
  @override
  _HallCouponFeeFormState createState() => _HallCouponFeeFormState();
}

class _HallCouponFeeFormState extends State<HallCouponFeeForm> {
  String? hall;
  String? roll;
  DateTime? selectedDate;
  final List<String> halls = ['Ahsanullah', 'Shahid Smrity', 'Bangabandhu'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(labelText: 'Hall'),
            value: hall,
            items: halls.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
            onChanged: (v) => setState(() => hall = v),
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Roll'),
            onChanged: (v) => setState(() => roll = v),
          ),
          SizedBox(height: 16),
          Text('Select Date:'),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
              }
            },
            child: Text(selectedDate == null ? 'Pick Date' : selectedDate!.toLocal().toString().split(' ')[0]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Validation and next step
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Hall Coupon Fee Submitted')),
              );
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}
