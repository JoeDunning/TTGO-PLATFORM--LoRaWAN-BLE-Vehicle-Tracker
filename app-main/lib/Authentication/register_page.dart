/*

RegisterPage  - Page Class/Handler

- class RegisterPage extends StatefulWidget

- class _RegisterPageState extends State<RegisterPage>

    //  State Handling
    @override void dispose()    // Called during disposing of state

    // Build Method
    Widget build(BuildContext context)

    // Utility Methods
    Future signUp() async       // Function for prompting & waiting for user sign up / user creation
    bool passwordConfirmed()    // Function for info checking / user sign in handling


*/

// Import Flutter Packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/*
----------- Code Section Start -----------
*/

// RegisterPage State Definition
class RegisterPage extends StatefulWidget {
  final VoidCallback showLoginPage;
  const RegisterPage({Key? key,required this.showLoginPage}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

// RegisterPage State Class Definition
class _RegisterPageState extends State<RegisterPage> {

  /*
  ----------- Definitions & Variables -----------
  */

  final _emailController = TextEditingController();             // Email Text Controller
  final _passwordController = TextEditingController();          // Info Controller
  final _confirmPasswordController = TextEditingController();   // Confirm Text Controller

  /*
  ----------- State Handling -----------
  */

  // Called during disposing of state
  @override
  void dispose() {
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
      backgroundColor : Colors.grey[300],
      body:SafeArea(
        child:Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_android,
                  size: 150,
                ),

                const Divider(height: 50),

                const Text(''
                    'Hello again',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize:36,
                  ),
                ),

                const Divider(height: 10),

                const Text(''
                    "Enter your Registration details below ",
                  style: TextStyle( fontSize:20,
                  ),
                ),

                const Divider(height: 50),

                // Email Text Field
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
                        controller: _emailController, //gets access to what the user puts inside the text fields
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Email',

                        ),
                      ),
                    ),
                  ),
                ),

                const Divider(height:  10),

                // Password Text Field
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

                const Divider(height: 10),

                //Confirm password textfield
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
                        controller: _confirmPasswordController, //gets access to what the user puts inside the text fields
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Confirm Password',
                        ),
                      ),
                    ),
                  ),

                ),

                const Divider(height: 10),

                // Sign-in Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: GestureDetector(
                    onTap: signUp,
                    child: Container(
                      padding:const EdgeInsets.all(20) ,
                      decoration: BoxDecoration(color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(12),
                      ) ,
                      child: const Center(
                        child: Text(
                          'Sign Up',
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

                const Divider(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("I am a member",style: TextStyle( fontWeight: FontWeight.bold,)),
                    GestureDetector(
                        onTap:widget.showLoginPage,
                        child: const Text(" Login Now",style: TextStyle(color: Colors.blue,fontWeight: FontWeight.bold,))),
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

  // Function for prompting & waiting for user sign up / user creation
  Future signUp() async {
    if(passwordConfirmed()){
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
    }
  }

  // Function for info checking / user sign in handling
  bool passwordConfirmed() {
    if (_passwordController.text.trim() ==
        _confirmPasswordController.text.trim()){
      return true;
    } else{
      return false;
    }
  }
}