import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      final user = Supabase.instance.client.auth.currentUser;
      if (!context.mounted) return;
      context.go(user == null ? '/login' : '/home');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
