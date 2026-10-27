import 'package:flutter/services.dart';
import '../models/vehicle_profile.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
  });

  String get googleMapsUrl => 'https://maps.google.com/?q=$latitude,$longitude';
}

class AssistantService {
  static const MethodChannel _channel = MethodChannel('com.voltdrive.app/assistant');

  static Future<bool> isOverlayGranted() async {
    try {
      final res = await _channel.invokeMethod<bool>('isOverlayGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestOverlayPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestOverlayPermission');
      return res ?? false;
    } catch (_) {
      try {
        await _channel.invokeMethod('openAppSettings');
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  static Future<bool> isAccessibilityEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestAccessibilityPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestAccessibilityPermission');
      return res ?? false;
    } catch (_) {
      try {
        await _channel.invokeMethod('openAppSettings');
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  static Future<void> showTestOffer() async {
    try {
      await _channel.invokeMethod('showTestOffer');
    } catch (_) {}
  }

  static Future<void> hideOverlay() async {
    try {
      await _channel.invokeMethod('hideOverlay');
    } catch (_) {}
  }

  static Future<void> syncSettings(VehicleProfile profile) async {
    try {
      await _channel.invokeMethod('updateSettings', {
        'platformFee': profile.platformFeePercent,
        'energyCostPerKm': profile.energyCostPerKmPublic,
      });
    } catch (_) {}
  }

  static Future<LocationResult?> getCurrentLocation() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getLocation');
      if (map == null) return null;
      return LocationResult(
        latitude: (map['lat'] as num?)?.toDouble() ?? 38.65,
        longitude: (map['lng'] as num?)?.toDouble() ?? -9.15,
        accuracy: (map['accuracy'] as num?)?.toDouble() ?? 50.0,
        speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  static Future<void> sendEmergencySms({required String phone, required String message}) async {
    try {
      await _channel.invokeMethod('sendEmergencySms', {
        'phone': phone,
        'message': message,
      });
    } catch (_) {}
  }

  static Future<void> shareWhatsApp({required String phone, required String message}) async {
    try {
      await _channel.invokeMethod('shareWhatsApp', {
        'phone': phone,
        'message': message,
      });
    } catch (_) {}
  }
}
