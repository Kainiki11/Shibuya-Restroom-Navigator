import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_shibuya/env/env.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  // 初期位置を定義（例: 渋谷周辺）
  final _initialPosition = const LatLng(35.659108, 139.703728);
  final _initialDestination = const LatLng(35.659108, 139.703728);

  Map<MarkerId, Marker> markers = {};
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = Env.key;

  // 現在位置（初期位置としても利用）
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
    // 初期位置と目的地のマーカーを追加
    _addMarker(_initialPosition, "origin", BitmapDescriptor.defaultMarker);
    _addMarker(_initialDestination, "destination", BitmapDescriptor.defaultMarkerWithHue(90));
    _getPolyline();
  }

  void _getCurrentLocation() async {
    // 現在地の取得
    Position position = await Geolocator.getCurrentPosition(
      // ignore: deprecated_member_use
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    // 現在地が取得できた後にトイレの情報を更新
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

        // 現在地との距離でソート
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

        // マーカーを更新
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
    // カメラを初期位置に移動
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

 // 設備情報を表示するための共通ウィジェット
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
          hintText: "トイレ名を検索",
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
    );
  }

  Widget _buildToiletCarousel() {
    return SizedBox(
      height: 150,
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
                        toilet.imageUrl ?? 'https://via.placeholder.com/100',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            toilet.name.split(' ')[0],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            toilet.name.split(' ').skip(1).join(' '),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
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
      bottom: 80,
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
                    if (toilet.imageUrl != null)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            toilet.imageUrl!,
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

                    // 設備情報の表示
                    if (toilet.hasMaleToilet) _facilityItem(Icons.male, "男性用トイレ"),
                    if (toilet.hasFemaleToilet) _facilityItem(Icons.female, "女性用トイレ"),
                    if (toilet.hasChildToilet) _facilityItem(Icons.child_care, "こども用トイレ"),
                    if (toilet.hasAccessibleToilet) _facilityItem(Icons.accessible, "障害のある人用トイレ"),
                    if (toilet.hasBabyChair) _facilityItem(Icons.chair, "ベビーチェア"),
                    if (toilet.hasBabyCareRoom) _facilityItem(Icons.baby_changing_station, "ベビーケアルーム"),
                    if (toilet.hasAssistanceBed) _facilityItem(Icons.single_bed, "介助用ベッド"),
                    if (toilet.hasOstomateToilet) _facilityItem(Icons.medical_services, "オストメイト対応トイレ"),


                    const SizedBox(height: 16),
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
          },
        );
      },
    );
  }
}

class ToiletService {
  Future<List<Toilet>> fetchToilets(double latitude, double longitude) async {
    return [
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
    ];
  }
}

class Toilet {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final bool hasMaleToilet;
  final bool hasFemaleToilet;
  final bool hasChildToilet;
  final bool hasAccessibleToilet;
  final bool hasBabyChair;
  final bool hasBabyCareRoom;
  final bool hasAssistanceBed;
  final bool hasOstomateToilet;

  Toilet({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.hasMaleToilet = false,
    this.hasFemaleToilet = false,
    this.hasChildToilet = false,
    this.hasAccessibleToilet = false,
    this.hasBabyChair = false,
    this.hasBabyCareRoom = false,
    this.hasAssistanceBed = false,
    this.hasOstomateToilet = false,
  });
}
