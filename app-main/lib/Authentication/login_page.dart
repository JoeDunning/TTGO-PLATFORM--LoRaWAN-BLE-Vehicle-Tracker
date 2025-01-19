/*

LoginPage - Page Class/Handler

- class LoginPage extends StatefulWidget

- class _LoginPageState extends State<LoginPage>

    //  State Handling
    @override void dispose()    // Called during disposing of state

    // Build Method
    Widget build(BuildContext context)

    // Utility Methods
    Future signIn() async     // This function is called when the user clicks the "sign in" button

*/

// Import Flutter Packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import App Classes
import 'reset_password.dart';

/*
----------- Code Section Start -----------
*/

// LoginPage State Definition
class LoginPage extends StatefulWidget {
  final VoidCallback showRegisterPage;  // Method to give to gestureDetector

  const LoginPage({Key? key, required this.showRegisterPage}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// _LoginPageState Class Definition
class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();     // Email text editing controller
  final _passwordController = TextEditingController();  // Password text editing controller

  /*
  ----------- State Handling -----------
  */

  // Called during disposing of state
  @override
  void dispose() {
    // helps with memory management
    _emailController.dispose();
    _passwordController.dispose();
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

                //Hello again
                const Text(
                  'Hello again',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 36),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Welcome back",
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 50),

                //email text field
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
                        controller: _emailController, //gets access to what the user puts inside the text fields
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Email',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                //password text field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border:Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: TextField(
                        controller: _passwordController, //gets access to what the user puts inside the text fields
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Password',
                        ),
                      ),
                    ),
                  ),

                ),
                const SizedBox(height: 10),
                //sign in button
                Padding(
                  padding:const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [

                      GestureDetector(
                          onTap:()
                          {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context){return const ResetPasswordPage();

                                },
                              ),
                            );
                          },
                          child: const Text(" Forgot password",style: TextStyle(color: Colors.blue,fontWeight: FontWeight.bold,))),

                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: GestureDetector(
                    onTap: signIn,
                    child: Container(
                      padding:const EdgeInsets.all(20) ,
                      decoration: BoxDecoration(color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(12),
                      ) ,


                      child: const Center(
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                            color : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),

                        ),
                      ),

                    ),
                  ),

                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    const Text("Not a member?",style: TextStyle( fontWeight: FontWeight.bold,)),
                    GestureDetector(
                        onTap:widget.showRegisterPage,
                        child: const Text(" Register Now",style: TextStyle(color: Colors.blue,fontWeight: FontWeight.bold,))),
                  ],
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

  // This function is called when the user clicks the "sign in" button
  Future signIn() async {
    // Show a circular loading indicator while we attempt to sign in
    showDialog(
      context: context,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Try to sign in with the user's email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());

      // If sign in is successful, remove the loading indicator
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      // If sign in fails due to an FirebaseAuthException (e.g. wrong password),
      // show an error message and remove the loading indicator
      Navigator.of(context).pop();
      String errorMessage;
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        errorMessage = 'Username/password incorrect';
      } else {
        errorMessage = 'Error signing in. Please try again later.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)));
    } catch (e) {
      // If sign in fails due to any other exception, show an error message
      // and remove the loading indicator
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error signing in. Please try again later.')));
    }
  }
}



