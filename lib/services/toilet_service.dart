import 'package:flutter_application_shibuya/screens/google_maps_api.dart';
import 'package:flutter_application_shibuya/screens/map_screen.dart';

class ToiletService {
  // トイレ情報を取得
  Future<List<Toilet>> fetchToilets(double latitude, double longitude) async {
    try {
      final toiletsData = await GoogleMapsApi.getToiletsNearby(latitude, longitude);

      return toiletsData.map((toiletData) {
        return Toilet(
          id: toiletData['id'],
          name: toiletData['name'],
          latitude: toiletData['latitude'],
          longitude: toiletData['longitude'],
          type: toiletData['type'],
          // wheelchairAccessible: toiletData['wheelchairAccessible'],
          // ostomateFriendly: toiletData['ostomateFriendly'],
        );
      }).toList();
    } catch (e) {
      print('Error fetching toilets: $e');
      return [];
    }
  }
}
