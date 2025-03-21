import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'my_text_field.dart';

typedef FutureCallback<T> = Future<T> Function();

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  var _redirecting = false;
  var _isLoading = false;
  // var _shouldCreateUser = true;
  late final StreamSubscription<AuthState> _authStateSubscription;

  // final _emailController = TextEditingController(text: 'someone@example.com');
  // final _passwordController = TextEditingController(
  //   text: 'rBTWSCWtdgbdaEuhisNF',
  // );
  // final _userNameController = TextEditingController(text: 'example taro');
  final _magicLinkEmailController = TextEditingController(
    text: 'wizardeveryone@example.com',
  );

  @override
  void initState() {
    super.initState();

    _authStateSubscription = supabase.auth.onAuthStateChange.listen((event) {
      debugPrint('event: ${event.event.toString()}');
      if (_redirecting) {
        return;
      }
      final session = event.session;
      if (session != null) {
        _redirecting = true;
        Navigator.of(context).pushReplacementNamed('/login-after');
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Text('Sign in with GitHub',
                //     style: Theme.of(context).textTheme.headlineSmall),
                // const Gap(8.0),
                // ElevatedButton(
                //   onPressed: _isLoading ? null : _signInGitHub,
                //   child: Text(_isLoading ? 'Loading' : 'Sign in with GitHub'),
                // ),
                // const Gap(8.0),
                // const Divider(color: Colors.orange, thickness: 3.0),
                // Text('Sign in with Email / Sign up with Email ',
                //     style: Theme.of(context).textTheme.headlineSmall),
                // MyTextField(
                //   label: 'Email',
                //   controller: _emailController,
                // ),
                // const Gap(8.0),
                // MyTextField(
                //   label: 'password',
                //   controller: _passwordController,
                // ),
                // const Gap(8.0),
                // MyTextField(
                //   label: 'user_name',
                //   controller: _userNameController,
                // ),
                // const Gap(8.0),
                // ElevatedButton(
                //   onPressed: _isLoading ? null : _signInEmail,
                //   child:
                //       Text(_isLoading ? 'Loading' : 'Sign in Email and Password'),
                // ),
                // const Gap(8.0),
                // ElevatedButton(
                //   onPressed: _isLoading ? null : _signUpEmail,
                //   child:
                //       Text(_isLoading ? 'Loading' : 'Sign up Email and Password'),
                // ),
                // const Gap(8.0),
                // const Divider(color: Colors.orange, thickness: 3.0),
                const Text(
                  'Weightloss Squad',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Text(
                  'Sign in with magic link',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    label: Text('email for magic link'),
                    hintText: 'foobar@example.com',
                  ),
                  controller: _magicLinkEmailController,
                ),
                // CheckboxListTile.adaptive(
                //   title: const Text('shouldCreateUser(default: true)'),
                //   value: _shouldCreateUser,
                //   onChanged: (value) {
                //     if (value != null) {
                //       setState(() => _shouldCreateUser = value);
                //     }
                //   },
                // ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signInMagicLink,
                  child: Text(
                    _isLoading ? 'Loading' : 'Sign in with magic link',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Future<void> _signInMagicLink() async {
  //   await _signInFlow(() async {
  //     await supabase.auth.signInWithOtp(
  //       email: _magicLinkEmailController.text,
  //       shouldCreateUser: true,
  //       // shouldCreateUser: _shouldCreateUser,
  //       // 下記URLがsupabase projectのRedirect URLsと一致していないと、リダイレクト後サインインできない(仕様)
  //       // ref: https://github.com/supabase/supabase/issues/11995#issuecomment-1647874100
  //       emailRedirectTo: 'io.supabase.weightlosssquad://login-callback/',
  //     );
  //   });
  // }


  Future<void> _signInMagicLink() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await supabase.auth.signInWithOtp(
        email: _magicLinkEmailController.text,
        shouldCreateUser: true,
        // 下記URLがsupabase projectのRedirect URLsと一致していないと、リダイレクト後サインインできない(仕様)
        emailRedirectTo: 'io.supabase.weightlosssquad://login-callback/',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please check your email and log in!'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error has occurred: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  // Future<void> _signUpEmail() async {
  //   await _signInFlow(() async {
  //     final auth = await supabase.auth.signUp(
  //       email: _emailController.text,
  //       password: _passwordController.text,
  //       data: {'user_name': _userNameController.text},
  //     );
  //     debugPrint('auth: $auth');
  //   });
  // }

  // Future<void> _signInEmail() async {
  //   await _signInFlow(() async {
  //     final auth = await supabase.auth.signInWithPassword(
  //       email: _emailController.text,
  //       password: _passwordController.text,
  //     );
  //     debugPrint('auth: $auth');
  //   });
  // }

  // Future<void> _signInGitHub() async {
  //   await _signInFlow(() async {
  //     await supabase.auth.signInWithOAuth(
  //       OAuthProvider.github,
  //       redirectTo: 'io.supabase.weightlosssquad://login-callback/',
  //     );
  //   });
  // }

  Future<void> _signInFlow(FutureCallback<void> attemptFutureFunc) async {
    try {
      setState(() {
        _isLoading = true;
      });
      await attemptFutureFunc();
    } catch (error) {
      debugPrint('error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected Error. $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
