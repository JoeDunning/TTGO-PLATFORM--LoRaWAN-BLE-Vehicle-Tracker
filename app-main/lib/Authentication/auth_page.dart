/*
AuthPage - Authentication Class

- class AuthPage extends StatefulWidget

- class _AuthPageState extends State<AuthPage>

    // Build Method
    Widget build(BuildContext context)

    // Utility Methods
    void toggleScreens()    // Function that toggles the value of the `showLoginPage` state variable.
*/

// Import Flutter Packages
import 'package:flutter/material.dart';

// Import App Classes
import 'login_page.dart';
import 'register_page.dart';

/*
----------- Code Section Start -----------
*/

// AuthPage State Definition
class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

// _AuthPageState Class Definition
class _AuthPageState extends State<AuthPage> {
  // The state variable that keeps track of whether the login or register page should be shown.
  bool showLoginPage = true;

  /*
  ----------- Widget Build Section -----------
  */

  @override
  Widget build(BuildContext context) {
    // Check the value of the `showLoginPage` state variable to determine which page to show.
    if(showLoginPage) {
      return LoginPage(showRegisterPage: toggleScreens); // Both of these activate when the blue register now button is clicked
    } else {
      return RegisterPage(showLoginPage: toggleScreens);
    }
  }

  /*
  ----------- Utility Methods -----------
  */

  // Function that toggles the value of the `showLoginPage` state variable.
  void toggleScreens() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }
}