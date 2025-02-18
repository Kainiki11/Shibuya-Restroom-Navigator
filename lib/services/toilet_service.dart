import 'package:test_project/screens/google_maps_api.dart';
import 'package:test_project/screens/map_screen.dart';

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
          imageUrl: toiletData['imageUrl'],
          hasMaleToilet: toiletData['hasMaleToilet'],
          hasFemaleToilet: toiletData['hasFemaleToilet'],
          hasChildToilet: toiletData['hasChildToilet'],
          hasAccessibleToilet: toiletData['hasAccessibleToilet'],
          hasBabyChair: toiletData['hasBabyChair'],
          hasBabyCareRoom: toiletData['hasBabyCareRoom'],
          hasAssistanceBed: toiletData['hasAssistanceBed'],
          hasOstomateToilet: toiletData['hasOstomateToilet'],
        );

      }).toList();
    } catch (e) {
      print('Error fetching toilets: $e');
      return [];
    }
  }
}
