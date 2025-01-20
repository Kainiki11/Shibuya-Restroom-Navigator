import 'package:flutter/material.dart';
import 'package:flutter_application_shibuya/env/env.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
    late GoogleMapController mapController;
  double _originLatitude = 6.5212402, _originLongitude = 3.3679965;
  double _destLatitude = 6.849660, _destLongitude = 3.648190;
  // double _originLatitude = 26.48424, _originLongitude = 50.04551;
  // double _destLatitude = 26.46423, _destLongitude = 50.06358;
  Map<MarkerId, Marker> markers = {};
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = Env.key;
  LatLng _currentPosition = const LatLng(35.6595, 139.7006);
  final ToiletService _toiletService = ToiletService();
  double _currentZoom = 15.0; // 初期ズームレベル
  List<Toilet> _toilets = [];
  Set<Marker> _markers = {};
  String _searchQuery = '';
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadToiletMarkers();
    /// origin marker
    _addMarker(LatLng(_originLatitude, _originLongitude), "origin",
        BitmapDescriptor.defaultMarker);

    /// destination marker
    _addMarker(LatLng(_destLatitude, _destLongitude), "destination",
        BitmapDescriptor.defaultMarkerWithHue(90));
    _getPolyline();
  }

  // ズームレベルを更新するメソッド
  void _updateZoomLevel(bool zoomIn) {
    final newZoom = zoomIn ? _currentZoom + 1 : _currentZoom - 1;

    // ズームレベルが許容範囲内か確認
    if (newZoom < 2 || newZoom > 20) return;

    setState(() {
      _currentZoom = newZoom;
    });

    // ズームレベルを反映
    mapController.animateCamera(CameraUpdate.zoomTo(_currentZoom));
  }
  
  void _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      // ignore: deprecated_member_use
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  void _loadToiletMarkers() async {
    try {
      final toilets = await _toiletService.fetchToilets();
      setState(() {
        _toilets = toilets;
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

  void _searchAndMoveToToilet() {
    final matchingToilet = _toilets.firstWhere(
      (toilet) =>
          toilet.name.toLowerCase().contains(_searchQuery.toLowerCase()),
    );

    mapController.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(matchingToilet.latitude, matchingToilet.longitude),
      ),
    );

    _drawRoute(
      LatLng(matchingToilet.latitude, matchingToilet.longitude),
    );
    }

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
  }

  _addMarker(LatLng position, String id, BitmapDescriptor descriptor) {
    MarkerId markerId = MarkerId(id);
    Marker marker =
        Marker(markerId: markerId, icon: descriptor, position: position);
    markers[markerId] = marker;
  }
  
  _addPolyLine() {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(
        polylineId: id, color: Colors.red, points: polylineCoordinates);
    polylines[id] = polyline;
    setState(() {});
  }

  _getPolyline() async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleAPiKey,
      request: PolylineRequest(
        origin: PointLatLng(_originLatitude, _originLongitude),
        destination: PointLatLng(_destLatitude, _destLongitude),
        mode: TravelMode.driving,
        wayPoints: [PolylineWayPoint(location: "Sabo, Yaba Lagos Nigeria")],
      ),
    );
    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }
    _addPolyLine();
  }
  
  Future<void> _drawRoute(LatLng destination) async {
    final String apiKey = Env.key; // APIキーを設定
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: "トイレ名を検索",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
        onSubmitted: (value) {
          setState(() {
            _searchQuery = value;
            _searchAndMoveToToilet();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shibuya Restroom Navigator"),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 15.0,
                  ),
                  onMapCreated: _onMapCreated,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 80,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoom_in",
                  onPressed: () => _updateZoomLevel(true), // ズームイン
                  mini: true,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoom_out",
                  onPressed: () => _updateZoomLevel(false), // ズームアウト
                  mini: true,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ToiletService {
  Future<List<Toilet>> fetchToilets() async {
    return [
      Toilet(
        id: "1",
        name: "渋谷駅前公衆トイレ",
        type: "公衆トイレ",
        latitude: 35.658033,
        longitude: 139.701635,
      ),
      Toilet(
        id: "2",
        name: "商業施設トイレ A",
        type: "商業施設",
        latitude: 35.659564,
        longitude: 139.700556,
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

  Toilet({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
  });
}
