import 'package:flutter/services.dart';
import '../models/vehicle_profile.dart';

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

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<bool> isAccessibilityEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
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
}
