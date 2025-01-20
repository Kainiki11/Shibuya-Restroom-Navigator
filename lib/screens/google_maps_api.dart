import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleMapsApi {
  static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // 自分のAPIキーを設定

  // 近くのトイレを検索
  static Future<List<Map<String, dynamic>>> getToiletsNearby(double latitude, double longitude) async {
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
}
