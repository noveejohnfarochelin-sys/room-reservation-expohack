import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:room_reservation_expohack/firebase_options.dart';
import 'package:room_reservation_expohack/screens/role_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const Tech4IsatuApp());
}

class Tech4IsatuApp extends StatelessWidget {
  const Tech4IsatuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tech4ISATU Room Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A4E8A)),
      ),
      home: const RoleLoginScreen(),
    );
  }
}