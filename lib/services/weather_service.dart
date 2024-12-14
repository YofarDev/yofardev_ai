// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _baseUrl =
      "https://api.openweathermap.org/data/2.5/weather";

  static Future<String> getCurrentWeather(String location) async {
    try {
      late double latitude;
      late double longitude;
      if (location.toLowerCase() == 'current') {
        // Get current location
        final Position position = await _determinePosition();
        latitude = position.latitude;
        longitude = position.longitude;
      } else {
        // Get coordinates from location name
        final List<Location> locations = await locationFromAddress(location);
        if (locations.isNotEmpty) {
          latitude = locations.first.latitude;
          longitude = locations.first.longitude;
        } else {
          return "Location not found.";
        }
      }
      final String apiKey = dotenv.env['OPEN_WEATHER_KEY'] ?? '';
      final Uri url = Uri.parse(
        "$_baseUrl?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric",
      );
      final http.Response response = await http.get(url);
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final Map<String, dynamic> map = <String, dynamic>{
          'description':
              ((data as Map<String, dynamic>)['weather'] as List<dynamic>)
                      .first['description'] as String? ??
                  '',
          'temperature_celsius': (data['main'] as Map<String, dynamic>)['temp'] as double?,
        };
        return jsonEncode(map);
      } else {
        return "Error fetching weather data: ${response.statusCode}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  static Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future<Position>.error('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future<Position>.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future<Position>.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }
    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }
}
