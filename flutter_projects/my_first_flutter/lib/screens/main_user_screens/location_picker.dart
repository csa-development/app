import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../widgets/top_toast.dart';

// ============================================================
// LOCATION PICKER
//
// Full-screen map for picking where an incident happened. The pin
// stays fixed in the centre of the screen and the map moves under
// it (same pattern as most ride-hailing/delivery apps) — reading the
// coordinate is just "wherever the map's centre currently is".
//
// Returns a Map with 'address', 'latitude', 'longitude' via
// Navigator.pop, or null if the user backs out without confirming.
// ============================================================

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const Color primaryBlue = Color(0xFF00334D);

  // Falls back to Accra if GPS isn't available/granted — same default
  // used for the static office map elsewhere in the app.
  static const LatLng _fallbackLocation = LatLng(5.6037, -0.1870);

  final MapController _mapController = MapController();

  LatLng _center = _fallbackLocation;
  String? _address;
  bool _isResolvingAddress = false;
  bool _isLocatingDevice = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _useCurrentLocation(showErrors: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _useCurrentLocation({bool showErrors = true}) async {
    setState(() => _isLocatingDevice = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showErrors) _showMessage('Please turn on location services');
        setState(() => _isLocatingDevice = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showErrors) {
          _showMessage(
            'Location permission denied — drag the map to pick a spot instead',
          );
        }
        setState(() => _isLocatingDevice = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() => _center = newCenter);
      _mapController.move(newCenter, 16);
      _resolveAddress(newCenter);
    } catch (e) {
      if (showErrors) _showMessage('Could not get your current location');
    } finally {
      if (mounted) setState(() => _isLocatingDevice = false);
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      final newCenter = _mapController.camera.center;
      setState(() => _center = newCenter);
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => _resolveAddress(newCenter),
      );
    }
  }

  // Free, no-API-key reverse geocoding via OpenStreetMap's own
  // Nominatim service. Their usage policy requires a real,
  // identifying User-Agent header rather than a generic HTTP client
  // string.
  Future<void> _resolveAddress(LatLng point) async {
    setState(() => _isResolvingAddress = true);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${point.latitude}&lon=${point.longitude}',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'CSA-Mobile-App/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _address = data['display_name'] as String? ??
              '${point.latitude.toStringAsFixed(5)}, '
                  '${point.longitude.toStringAsFixed(5)}';
        });
      } else {
        setState(() {
          _address = '${point.latitude.toStringAsFixed(5)}, '
              '${point.longitude.toStringAsFixed(5)}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _address = '${point.latitude.toStringAsFixed(5)}, '
            '${point.longitude.toStringAsFixed(5)}';
      });
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  void _showMessage(String message) {
    showTopToast(
      context,
      message,
      isError: false,
      backgroundColor: Colors.black54,
      icon: Icons.info_outline,
    );
  }

  void _confirm() {
    Navigator.pop(context, {
      'address': _address ??
          '${_center.latitude.toStringAsFixed(5)}, '
              '${_center.longitude.toStringAsFixed(5)}',
      'latitude': _center.latitude,
      'longitude': _center.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Pick a Location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.my_first_flutter',
              ),
            ],
          ),

          // Fixed centre pin — the map moves underneath it, so this
          // never redraws on its own.
          const IgnorePointer(
            child: Center(
              child: Padding(
                // Nudged up by half the pin's height so its TIP (not
                // its centre) points at the map's actual centre.
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 44,
                ),
              ),
            ),
          ),

          // "Use my location" button, floating over the map.
          Positioned(
            right: 16,
            bottom: 170,
            child: FloatingActionButton(
              heroTag: 'use_current_location',
              backgroundColor: Colors.white,
              foregroundColor: primaryBlue,
              onPressed: _isLocatingDevice ? null : _useCurrentLocation,
              child: _isLocatingDevice
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          // Bottom panel — resolved address + confirm button.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 18, color: primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isResolvingAddress
                              ? const Text(
                                  'Finding address…',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black45),
                                )
                              : Text(
                                  _address ?? 'Move the map to pick a spot',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _isResolvingAddress ? null : _confirm,
                        child: const Text(
                          'CONFIRM LOCATION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
