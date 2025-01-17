import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_shibuya/env/env.dart';
import 'package:firebase_core/firebase_core.dart';  // Firebase Core パッケージをインポート
import 'screens/map_screen.dart';
import 'firebase_options.dart';

void main() async {
  // Flutter 初期化
  WidgetsFlutterBinding.ensureInitialized();

  const platform = MethodChannel('com.example.flutterApplicationShibuya/api');
  platform.invokeMethod('setApiKey', Env.key);

  // Firebase 初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(ShibuyaToiletApp());
}

class ShibuyaToiletApp extends StatelessWidget {
  const ShibuyaToiletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shibuya Restroom Navigator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapScreen(),
    );
  }
}