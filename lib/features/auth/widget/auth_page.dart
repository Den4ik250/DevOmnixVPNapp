import 'package:flutter/material.dart';

/// Stub — device auth is now handled silently at startup via AuthNotifier.init().
/// This page is kept only so the '/auth' GoRoute continues to compile.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
