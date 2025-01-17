import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ignore: unused_field
  late GoogleMapController _mapController;
  LatLng _currentPosition = const LatLng(35.6595, 139.7006); // 渋谷駅付近
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadToiletMarkers();
  }

  void _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // サービスが有効か確認
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // サービスが無効の場合
      return Future.error('Location services are disabled.');
    }

    // 権限の状態を確認
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 権限が拒否されている場合にリクエスト
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 権限が再度拒否された場合
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // ユーザーが今後権限を拒否した場合
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // 権限が許可された場合に位置情報を取得
    Position position = await Geolocator.getCurrentPosition(
      // ignore: deprecated_member_use
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }


  void _loadToiletMarkers() {
    // 仮のトイレデータ
    final toilets = [
      {"lat": 35.6591, "lng": 139.7012, "name": "公衆トイレ A"},
      {"lat": 35.6603, "lng": 139.6998, "name": "商業施設トイレ B"},
    ];

    setState(() {
      _markers = toilets
          .map((toilet) => Marker(
                markerId: MarkerId(toilet['name'] as String),
                position: LatLng(toilet['lat'] as double, toilet['lng'] as double),
                infoWindow: InfoWindow(title: toilet['name'] as String),
              ))
          .toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shibuya Restroom Navigator")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
        markers: _markers,
        myLocationEnabled: true,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }
}
