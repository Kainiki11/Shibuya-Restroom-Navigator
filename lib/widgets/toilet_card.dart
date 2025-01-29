import 'package:flutter/material.dart';
import 'package:flutter_application_shibuya/screens/map_screen.dart';

class ToiletCard extends StatelessWidget {
  final Toilet toilet;

  const ToiletCard({required this.toilet, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(toilet.name),
        subtitle: Text(toilet.type),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          // 詳細画面に遷移
        },
      ),
    );
  }
}
