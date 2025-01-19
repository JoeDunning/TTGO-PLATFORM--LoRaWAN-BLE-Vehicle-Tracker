/*

ResetInfoPage  - Page Class/Handler

- class ResetInfoPage extends StatefulWidget

- class _ResetInfoPageState extends State<ResetInfoPage>

    //  State Handling
    @override void dispose()    // Called during disposing of state

    // Build Method
    Widget build(BuildContext context)

    // Utility Methods
    Future resetPassword() async    // Function for info reset

*/

// Import Flutter Packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/*
----------- Code Section Start -----------
*/

// ResetPasswordPage State Definition
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({Key? key}) : super(key: key);

  @override
  ResetPasswordPageState createState() => ResetPasswordPageState();
}

// ResetPasswordPage Class Definition
class ResetPasswordPageState extends State<ResetPasswordPage> {

  /*
  ----------- Definitions & Variables -----------
  */

  final _emailController = TextEditingController();

  /*
  ----------- State Handling -----------
  */

  // Called during disposing of state
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /*
  ----------- Widget Build Section -----------
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phone_android,
                  size: 150,
                ),
                const SizedBox(height: 50),

                // Title
                const Text(
                  'Reset Password',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 36),
                ),
                const SizedBox(height: 10),

                // Email text field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Email',
                        ),
                      ),
                    ),
                  ),
                ),

                // Reset password button
                const SizedBox(height: 10),
                ElevatedButton (
                  onPressed: resetPassword,
                  child: const Text("Reset Password"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*
  ----------- Utility Methods -----------
  */

  // Function for info reset
  Future resetPassword() async {
    // Show loading indicator
    showDialog(
      context: context,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim()); // Send info reset email

    Navigator.of(context).pop(); // Remove loading indicator
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password reset email sent"))); // Show success message
  }
}