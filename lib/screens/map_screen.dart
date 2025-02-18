import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:test_project/env/env.dart';
import 'package:test_project/screens/language/global_language.dart';
import 'package:translator/translator.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  final _initialPosition = const LatLng(35.659108, 139.703728);
  final _initialDestination = const LatLng(35.659108, 139.703728);

  Map<MarkerId, Marker> markers = {};
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = Env.key;

  var _currentPosition = const LatLng(35.659108, 139.703728);

  final ToiletService _toiletService = ToiletService();
  List<Toilet> _toilets = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadToiletMarkers();
    _addMarker(_initialPosition, "origin", BitmapDescriptor.defaultMarker);
    _addMarker(_initialDestination, "destination", BitmapDescriptor.defaultMarkerWithHue(90));
    _getPolyline();
  }

  void _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _loadToiletMarkers();
  }

  void _loadToiletMarkers() async {
    try {
      final toilets = await _toiletService.fetchToilets(
        _currentPosition.latitude,
        _currentPosition.longitude,
      );
      setState(() {
        _toilets = toilets;

        _toilets.sort((a, b) {
          final distanceA = Geolocator.distanceBetween(
            _currentPosition.latitude,
            _currentPosition.longitude,
            a.latitude,
            a.longitude,
          );
          final distanceB = Geolocator.distanceBetween(
            _currentPosition.latitude,
            _currentPosition.longitude,
            b.latitude,
            b.longitude,
          );
          return distanceA.compareTo(distanceB);
        });

        _updateMarkers();
      });
    } catch (e) {
      print('Error loading toilets: $e');
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers = _toilets
          .map((toilet) => Marker(
                markerId: MarkerId(toilet.id),
                position: LatLng(toilet.latitude, toilet.longitude),
                infoWindow: InfoWindow(title: toilet.name),
              ))
          .toSet();
    });
  }

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _initialPosition,
          zoom: 15.0,
        ),
      ),
    );
  }

  void _addMarker(LatLng position, String id, BitmapDescriptor descriptor) {
    MarkerId markerId = MarkerId(id);
    Marker marker = Marker(markerId: markerId, icon: descriptor, position: position);
    markers[markerId] = marker;
  }

  void _addPolyLine() {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(
        polylineId: id, color: Colors.red, points: polylineCoordinates);
    polylines[id] = polyline;
    setState(() {});
  }

  Widget _facilityItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _getPolyline() async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: Env.key,
      request: PolylineRequest(
        origin: PointLatLng(_initialPosition.latitude, _initialPosition.longitude),
        destination: PointLatLng(_initialDestination.latitude, _initialDestination.longitude),
        mode: TravelMode.driving,
      ),
    );
    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }
    _addPolyLine();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: selectedLanguage == Language.English
            ? "Search for toilet by name"
            : "トイレの名前で検索", // 言語に応じたヒントテキスト
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });

          if (_searchQuery.isEmpty) {
            _loadToiletMarkers();
          } else {
            _searchAndMoveToToilet();
          }
        },
      ),
    );
  }

  void _searchAndMoveToToilet() {
    final filteredToilets = _toilets.where((toilet) {
      return toilet.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredToilets.isNotEmpty) {
      setState(() {
        _toilets = filteredToilets;
      });

      final matchingToilet = filteredToilets.first;
      mapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(matchingToilet.latitude, matchingToilet.longitude),
        ),
      );
      _drawRoute(LatLng(matchingToilet.latitude, matchingToilet.longitude));
    } else {
      print('No matching toilets found.');
    }
  }

  Future<void> _drawRoute(LatLng destination) async {
    final String apiKey = Env.key;
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_currentPosition.latitude},${_currentPosition.longitude}&destination=${destination.latitude},${destination.longitude}&mode=walking&key=$apiKey');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'].isNotEmpty) {
        final points = data['routes'][0]['overview_polyline']['points'];
        final decodedPoints = _decodePolyline(points);

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blue,
              width: 5,
              points: decodedPoints,
            ),
          };
        });
      }
    } else {
      print('Failed to fetch directions: ${response.body}');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _initialPosition,
        zoom: 15.0,
      ),
      onMapCreated: _onMapCreated,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
    );
  }

  Widget _buildToiletCarousel() {
    return SizedBox(
      height: 165,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _toilets.length,
        itemBuilder: (context, index) {
          final toilet = _toilets[index];
          return GestureDetector(
            onTap: () {
              _showModal(context, toilet);
              _drawRoute(LatLng(toilet.latitude, toilet.longitude));
              mapController.animateCamera(CameraUpdate.newLatLngZoom(
                LatLng(toilet.latitude, toilet.longitude),
                17.0,
              ));
              setState(() {
                _markers = _markers.map((marker) {
                  if (marker.markerId.value == toilet.id) {
                    return marker.copyWith(
                      iconParam: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    );
                  }
                  return marker.copyWith(iconParam: BitmapDescriptor.defaultMarker);
                }).toSet();
              });
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: SizedBox(
                width: 173,
                height: 173,
                child: Wrap(
                  children: [
                    SizedBox(
                      width: 180,
                      height: 100,
                      child: Image.network(
                        toilet.imageUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Flexible( // ここに追加
                            child: Text(
                              toilet.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2, // トイレ名が2行まで表示
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentLocationButton() {
    return Positioned(
      bottom: 165,
      right: 16,
      child: FloatingActionButton(
        onPressed: () async {
          _getCurrentLocation();
          mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition));
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
              ],
            ),
          ),
                _buildCurrentLocationButton(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildToiletCarousel(),
          ),
        ],
      ),
    );
  }

  void _showModal(BuildContext context, Toilet toilet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, 
      isDismissible: true, // 🔥 地図タップで閉じる
      backgroundColor: Colors.transparent, // 🔥 背景を透明にする
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, 
          minChildSize: 0.3, 
          maxChildSize: 1.0, 
          expand: false, // ← これを false にすることで背景を透明にした時の影響を防ぐ
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white, // 🔥 ここだけ白くする
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          toilet.imageUrl,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      toilet.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text("${toilet.type}", style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    const SizedBox(height: 12),

                    if (toilet.facilities.containsKey('male')) _facilityItem(Icons.male, toilet.facilities['male']!),
                    if (toilet.facilities.containsKey('female')) _facilityItem(Icons.female, toilet.facilities['female']!),
                    if (toilet.facilities.containsKey('child')) _facilityItem(Icons.child_care, toilet.facilities['child']!),
                    if (toilet.facilities.containsKey('accessible')) _facilityItem(Icons.accessible, toilet.facilities['accessible']!),
                    if (toilet.facilities.containsKey('babyChair')) _facilityItem(Icons.chair, toilet.facilities['babyChair']!),
                    if (toilet.facilities.containsKey('babyCareRoom')) _facilityItem(Icons.baby_changing_station, toilet.facilities['babyCareRoom']!),
                    if (toilet.facilities.containsKey('assistanceBed')) _facilityItem(Icons.single_bed, toilet.facilities['assistanceBed']!),
                    if (toilet.facilities.containsKey('ostomate')) _facilityItem(Icons.medical_services, toilet.facilities['ostomate']!),



                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          selectedLanguage == Language.English ? "Back to Map" : "マップに戻る", // 言語に応じてテキストを変更
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ToiletService {
  final GoogleTranslator translator = GoogleTranslator();

  Future<List<Toilet>> fetchToilets(double latitude, double longitude) async {
    List<Toilet> toilets = [
      Toilet(
        id: "1",
        name: "はるのおがわコミュニティパークトイレ",
        type: "公衆トイレ",
        latitude: 35.6722453,
        longitude: 139.6910705,
        imageUrl: "https://lh5.googleusercontent.com/p/AF1QipPbTeUG829YuGoILZVeNLEDXFt2aw9hUIoCvWff=w408-h306-k-no",
        hasMaleToilet: true,
        hasFemaleToilet: true,
        hasChildToilet: false,
        hasAccessibleToilet: true,
        hasBabyChair: true,
        hasBabyCareRoom: false,
        hasAssistanceBed: false,
        hasOstomateToilet: true,
      ),
      Toilet(
        id: "2",
        name: "東三丁目公衆トイレ",
        type: "公衆トイレ",
        latitude: 35.6489531,
        longitude: 139.7091569,
        imageUrl: "https://tokyotoilet.jp/cms/wp-content/uploads/2020/08/HigashiToilet_07_A-2000x1318.jpg",
        hasMaleToilet: true,
        hasFemaleToilet: true,
        hasChildToilet: false,
        hasAccessibleToilet: true,
        hasBabyChair: false,
        hasBabyCareRoom: false,
        hasAssistanceBed: false,
        hasOstomateToilet: true,
      ),
      Toilet(
        id: "3",
        name: "恵比寿公園トイレ",
        type: "公衆トイレ",
        latitude: 35.6435511,
        longitude: 139.7087741,
        imageUrl: "https://tokyotoilet.jp/cms/wp-content/uploads/2020/08/O0A3232-1-2000x1333.jpg",
        hasMaleToilet: true,
        hasFemaleToilet: true,
        hasChildToilet: false,
        hasAccessibleToilet: true,
        hasBabyChair: true,
        hasBabyCareRoom: false,
        hasAssistanceBed: false,
        hasOstomateToilet: true,
      ),
      Toilet(
        id: "4",
        name: "鍋島松濤公園トイレ",
        type: "公衆トイレ",
        latitude: 35.6595319,
        longitude: 139.6915548,
        imageUrl: "https://tokyotoilet.jp/cms/wp-content/uploads/2021/07/O0A6933-2000x1333.jpg",
        hasMaleToilet: true,
        hasFemaleToilet: true,
        hasChildToilet: true,
        hasAccessibleToilet: true,
        hasBabyChair: true,
        hasBabyCareRoom: true,
        hasAssistanceBed: false,
        hasOstomateToilet: true,
      ),
      Toilet(
        id: "5",
        name: "笹塚緑道公衆トイレ",
        type: "公衆トイレ",
        latitude: 35.6733752,
        longitude: 139.6673582,
        imageUrl: "https://tokyotoilet.jp/cms/wp-content/uploads/2023/05/1G1A0857-640x427.jpg",
        hasMaleToilet: true,
        hasFemaleToilet: true,
        hasChildToilet: true,
        hasAccessibleToilet: true,
        hasBabyChair: true,
        hasBabyCareRoom: true,
        hasAssistanceBed: true,
        hasOstomateToilet: true,
      ),
      // 他のトイレも同様に続く
    ];

    // 言語に応じて設備情報を設定
    for (var toilet in toilets) {
      if (selectedLanguage == Language.English) {
        // 英語の場合は翻訳を行う
        toilet.name = (await translator.translate(toilet.name, to: 'en')).text;
        toilet.type = (await translator.translate(toilet.type, to: 'en')).text;
        toilet.facilities = await _translateFacilities(toilet);
      } else {
        // 日本語の場合は直接設定
        toilet.facilities = _setJapaneseFacilities(toilet);
      }
    }

    return toilets;
  }

  // 日本語の設備情報を設定
  Map<String, String> _setJapaneseFacilities(Toilet toilet) {
    final Map<String, String> facilities = {};

    if (toilet.hasMaleToilet) {
      facilities['male'] = '男性用トイレ';
    }
    if (toilet.hasFemaleToilet) {
      facilities['female'] = '女性用トイレ';
    }
    if (toilet.hasChildToilet) {
      facilities['child'] = 'こども用トイレ';
    }
    if (toilet.hasAccessibleToilet) {
      facilities['accessible'] = '多目的トイレ';
    }
    if (toilet.hasBabyChair) {
      facilities['babyChair'] = 'ベビーチェア';
    }
    if (toilet.hasBabyCareRoom) {
      facilities['babyCareRoom'] = 'ベビーケアルーム';
    }
    if (toilet.hasAssistanceBed) {
      facilities['assistanceBed'] = '介助用ベッド';
    }
    if (toilet.hasOstomateToilet) {
      facilities['ostomate'] = 'オストメイト対応トイレ';
    }

    return facilities;
  }

  // 英語への翻訳（既存のメソッド）
  Future<Map<String, String>> _translateFacilities(Toilet toilet) async {
    final Map<String, String> translatedFacilities = {};

    if (toilet.hasMaleToilet) {
      translatedFacilities['male'] = (await translator.translate('男性用トイレ', to: 'en')).text;
    }
    if (toilet.hasFemaleToilet) {
      translatedFacilities['female'] = (await translator.translate('女性用トイレ', to: 'en')).text;
    }
    if (toilet.hasChildToilet) {
      translatedFacilities['child'] = (await translator.translate('こども用トイレ', to: 'en')).text;
    }
    if (toilet.hasAccessibleToilet) {
      translatedFacilities['accessible'] = (await translator.translate('多目的トイレ', to: 'en')).text;
    }
    if (toilet.hasBabyChair) {
      translatedFacilities['babyChair'] = (await translator.translate('ベビーチェア', to: 'en')).text;
    }
    if (toilet.hasBabyCareRoom) {
      translatedFacilities['babyCareRoom'] = (await translator.translate('ベビーケアルーム', to: 'en')).text;
    }
    if (toilet.hasAssistanceBed) {
      translatedFacilities['assistanceBed'] = (await translator.translate('介助用ベッド', to: 'en')).text;
    }
    if (toilet.hasOstomateToilet) {
      translatedFacilities['ostomate'] = (await translator.translate('オストメイト対応トイレ', to: 'en')).text;
    }

    return translatedFacilities;
  }
}


class Toilet {
  String id;
  String name;
  String type;
  double latitude;
  double longitude;
  String imageUrl;
  bool hasMaleToilet;
  bool hasFemaleToilet;
  bool hasChildToilet;
  bool hasAccessibleToilet;
  bool hasBabyChair;
  bool hasBabyCareRoom;
  bool hasAssistanceBed;
  bool hasOstomateToilet;
  
  // 設備翻訳用のマップ
  Map<String, String> facilities = {};

  Toilet({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.hasMaleToilet,
    required this.hasFemaleToilet,
    required this.hasChildToilet,
    required this.hasAccessibleToilet,
    required this.hasBabyChair,
    required this.hasBabyCareRoom,
    required this.hasAssistanceBed,
    required this.hasOstomateToilet,
  });
}
