import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import '../home/business_home_screen.dart' deferred as business_home;
import '../home/user_dashboard_screen.dart' deferred as user_dashboard;

// --- 1. AuthWrapper (Modificado) ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        if (snapshot.hasData) {
          return RoleGate(userId: snapshot.data!.uid);
        }
        return const LoginScreen();
      },
    );
  }
}

// --- 2. RoleGate (Modificado) ---
class RoleGate extends StatelessWidget {
  final String userId;
  const RoleGate({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("Error al cargar datos")));
        }
        if (!snapshot.data!.exists || snapshot.data!.data() == null) {
          Future.microtask(() => FirebaseAuth.instance.signOut());
          return const LoginScreen(); 
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String? role = data['role'];

        if (role == 'business') {
          return _DeferredScreen(
            loadLibrary: business_home.loadLibrary,
            buildScreen: () => business_home.BusinessHomeScreen(),
          );
        } else if (role == 'user') {
          return _DeferredScreen(
            loadLibrary: user_dashboard.loadLibrary,
            buildScreen: () => user_dashboard.UserDashboardScreen(),
          );
        }

        Future.microtask(() => FirebaseAuth.instance.signOut());
        return const LoginScreen();
      },
    );
  }
}

class _DeferredScreen extends StatefulWidget {
  const _DeferredScreen({
    required this.loadLibrary,
    required this.buildScreen,
  });

  final Future<dynamic> Function() loadLibrary;
  final Widget Function() buildScreen;

  @override
  State<_DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<_DeferredScreen> {
  late final Future<dynamic> _library;

  @override
  void initState() {
    super.initState();
    _library = widget.loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _library,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('No se pudo cargar el panel. Intenta nuevamente.'),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        return widget.buildScreen();
      },
    );
  }
}

// --- Pantalla de Carga (Sin cambios) ---
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
