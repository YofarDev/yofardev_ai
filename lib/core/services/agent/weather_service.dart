// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../models/weather_report.dart';

class WeatherService {
  static const String _baseUrl =
      "https://api.openweathermap.org/data/2.5/weather";

  /// The weather as the JSON string the LLM reads.
  static Future<String> getCurrentWeather(
    String location,
    String apiKey,
  ) async {
    return (await fetchCurrentWeather(location, apiKey)).json;
  }

  /// Like [getCurrentWeather], and also the parsed [WeatherReport] when the
  /// call succeeded (null on any error; [json] then holds the error text).
  ///
  /// [allowPermissionPrompt] false makes `current` fail instead of asking for
  /// the location permission (the background world sync never asks).
  static Future<({String json, WeatherReport? report})> fetchCurrentWeather(
    String location,
    String apiKey, {
    bool allowPermissionPrompt = true,
  }) async {
    try {
      if (apiKey.isEmpty) {
        return (json: "Error: API Key not provided", report: null);
      }

      late double latitude;
      late double longitude;
      if (location.toLowerCase() == 'current') {
        // Get current location
        final Position position = await _determinePosition(
          allowPermissionPrompt: allowPermissionPrompt,
        );
        latitude = position.latitude;
        longitude = position.longitude;
      } else {
        // Get coordinates from location name
        final Geocoding geocoding = Geocoding();
        final List<Location> locations = await geocoding.locationFromAddress(
          location,
        );
        if (locations.isNotEmpty) {
          latitude = locations.first.latitude;
          longitude = locations.first.longitude;
        } else {
          return (json: "Location not found.", report: null);
        }
      }
      final Uri url = Uri.parse(
        "$_baseUrl?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric",
      );
      final http.Response response = await http.get(url);
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final Map<String, dynamic> body = data as Map<String, dynamic>;
        WeatherReport? report;
        try {
          report = WeatherReport.fromOpenWeather(body);
        } catch (_) {
          report = null;
        }
        final Map<String, dynamic> map = <String, dynamic>{
          'description':
              (body['weather'] as List<dynamic>).first['description']
                  as String? ??
              '',
          'temperature_celsius':
              ((body['main'] as Map<String, dynamic>)['temp'] as num?)
                  ?.toDouble(),
          'condition_id': ?report?.conditionId,
        };
        return (json: jsonEncode(map), report: report);
      } else {
        return (
          json: "Error fetching weather data: ${response.statusCode}",
          report: null,
        );
      }
    } catch (e) {
      return (json: "Error: $e", report: null);
    }
  }

  static Future<Position> _determinePosition({
    required bool allowPermissionPrompt,
  }) async {
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
      if (!allowPermissionPrompt) {
        return Future<Position>.error('Location permissions are denied');
      }
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
