import 'package:flutter/services.dart';

/// Stores only first-run completion; health entries remain session-only.
class SetupPreference {
  static const channel = MethodChannel('org.auracare/setup');
  Future<bool> completed() async {
    try {
      return await channel.invokeMethod<bool>('completed') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> complete() async {
    try {
      return await channel.invokeMethod<bool>('complete') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
