/*

MainPage - Page Class/View

- class MainPage extends StatelessWidget

    // Build Method
    Widget build(BuildContext context)

*/

// Import Flutter Packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import App Classes
import '../Pages/home_page.dart';
import 'auth_page.dart';

/*
----------- Code Section Start -----------
*/

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  /*
  ----------- Widget Build Section -----------
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      // Disable resizing of the screen when keyboard appears
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(), // Checking if the user has logged in or not (auth state changes)
        builder: (context,snapshot){
          if(snapshot.hasData){ // If user is logged in, show the HomePage
            return const HomePage();
          } else { // If user is not logged in, show the AuthPage
            return const AuthPage();
          }
        }
      )
    );
  }
}
