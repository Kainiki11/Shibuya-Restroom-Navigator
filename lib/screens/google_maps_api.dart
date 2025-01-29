import 'dart:convert';
import 'package:flutter_application_shibuya/env/env.dart';
import 'package:http/http.dart' as http;

class GoogleMapsApi {
  static final String _apiKey = Env.key; // 自分のAPIキーを設定

  // 近くのトイレを検索
  static Future<List<Map<String, dynamic>>> getToiletsNearby(
      double latitude, double longitude) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&type=toilet&key=$_apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<Map<String, dynamic>> toilets = [];
      for (var result in data['results']) {
        toilets.add({
          'name': result['name'],
          'latitude': result['geometry']['location']['lat'],
          'longitude': result['geometry']['location']['lng'],
          'id': result['place_id'],
          'type': '公衆トイレ', // トイレの種類（仮で公衆トイレとします）
          'wheelchairAccessible': result['types'].contains('wheelchair_accessible'),
          'ostomateFriendly': false, // ここはAPIの応答に依存します（仮）
        });
      }
      return toilets;
    } else {
      throw Exception('Failed to load nearby toilets');
    }
  }

  // トイレの詳細情報を取得
  static Future<Map<String, dynamic>> getToiletDetails(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['result'];

      // 必要な情報を抽出
      return {
        'name': result['name'],
        'address': result['formatted_address'],
        'phone': result['formatted_phone_number'] ?? '電話番号なし',
        'rating': result['rating'] ?? '評価なし',
        'website': result['website'] ?? 'ウェブサイトなし',
        'wheelchairAccessible': result['accessibility']?['wheelchair_accessible'] ?? false,
        'ostomateFriendly': false, // Place Details APIに応じた情報を追加可能
      };
    } else {
      throw Exception('Failed to load place details');
    }
  }

  // テスト用メソッド
  static Future<void> testNearbySearchAndDetails(
      double latitude, double longitude) async {
    try {
      print('Nearby toilets search...');
      List<Map<String, dynamic>> toilets =
          await getToiletsNearby(latitude, longitude);
      print('Found ${toilets.length} toilets:');

      for (var toilet in toilets) {
        print('Name: ${toilet['name']}, ID: ${toilet['id']}');
        print('Fetching details...');
        final details = await getToiletDetails(toilet['id']);
        print('Details: $details');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
