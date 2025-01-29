import 'package:flutter/material.dart';
import 'package:flutter_application_shibuya/screens/map_screen.dart';

class ToiletDetailScreen extends StatelessWidget {
  final Toilet toilet;

  const ToiletDetailScreen({super.key, required this.toilet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(toilet.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像を表示
            if (toilet.imageUrl != null)
              Center(
                child: Image.network(
                  toilet.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            // トイレの名前
            Text(
              toilet.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // トイレの種類
            Text("種類: ${toilet.type}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            // 位置情報
            Text("緯度: ${toilet.latitude}, 経度: ${toilet.longitude}",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            // Googleマップに戻るボタン
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("マップに戻る"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
