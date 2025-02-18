import 'package:flutter/material.dart';
import 'package:test_project/screens/language/global_language.dart';
import 'package:test_project/screens/map_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Language? _selectedLanguage = selectedLanguage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('日本語'),
            leading: Radio<Language>(
              value: Language.Japanese,
              groupValue: _selectedLanguage,
              onChanged: (Language? value) {
                setState(() {
                  _selectedLanguage = value;
                  selectedLanguage = value!;
                });
              },
            ),
          ),
          ListTile(
            title: const Text('English'),
            leading: Radio<Language>(
              value: Language.English,
              groupValue: _selectedLanguage,
              onChanged: (Language? value) {
                setState(() {
                  _selectedLanguage = value;
                  selectedLanguage = value!;
                });
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // 設定変更後、前の画面に戻る
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapScreen(),
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
