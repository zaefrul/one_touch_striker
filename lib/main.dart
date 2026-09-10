import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'account/auth_service.dart';
import 'app_session.dart';
import 'home/home_screen.dart';

const lime = Color(0xffd9ff6a);
const ink = Color(0xff062d29);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: ink,
  ));
  runApp(const StrikerApp());
}

class StrikerApp extends StatefulWidget {
  const StrikerApp({super.key, this.auth, this.session});

  final AuthService? auth;
  final StrikerSession? session;

  @override
  State<StrikerApp> createState() => _StrikerAppState();
}

class _StrikerAppState extends State<StrikerApp> {
  late final StrikerSession session;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    session = widget.session ?? StrikerSession(auth: widget.auth);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await session.boot();
    if (mounted) {
      setState(() => ready = true);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'One-Touch Striker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: const ColorScheme.dark(primary: lime, surface: ink),
          fontFamily: 'sans-serif',
          useMaterial3: true,
        ),
        home: ready
            ? HomeScreen(session: session)
            : const Scaffold(
                body: Center(
                  child: Icon(Icons.sports_soccer, color: lime, size: 36),
                ),
              ),
      );
}
