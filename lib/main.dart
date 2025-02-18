import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_core/firebase_core.dart'; // Firebase Core パッケージをインポート
import 'package:test_project/env/env.dart';
import 'package:test_project/screens/settings_screen.dart';
import 'firebase_options.dart';

void main() async {
  // Flutter 初期化
  WidgetsFlutterBinding.ensureInitialized();

  // 環境変数からAPIキーを設定
  const platform = MethodChannel('com.example.flutterApplicationShibuya/api');
  await platform.invokeMethod('setApiKey', Env.key);

  // Firebase 初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ShibuyaToiletApp());
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
      home: const SettingsScreen(), // MapScreenを初期画面に設定
    );
  }
}