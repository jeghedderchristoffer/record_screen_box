import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_plugin/flutter_foreground_plugin.dart';

class RecordScreenBox {
  static const MethodChannel _channel =
      const MethodChannel('screen_recorder_box');

  static Future<bool> startRecording(String name, String path) async {
    // First start forground service (only android)
    await startForgroundService();

    // Get device height and width to use for recording screen size
    double deviceHeight = WidgetsBinding.instance!.window.physicalSize.height;
    double deviceWidth = WidgetsBinding.instance!.window.physicalSize.width;

    // Start the screen recording
    bool isStarted = await _channel.invokeMethod('startScreenRecording', {
      'name': name,
      'height': deviceHeight,
      'width': deviceWidth,
      'path': path,
    });

    print(isStarted);

    // Stop foreground if not started...
    if (!isStarted && Platform.isAndroid) {
      await FlutterForegroundPlugin.stopForegroundService();
    }

    // Return state
    return isStarted;
  }

  static Future<String> stopRecording() async {
    final String path = await _channel.invokeMethod('stopScreenRecording');

    if (Platform.isAndroid) {
      await FlutterForegroundPlugin.stopForegroundService();
    }

    return path;
  }

  static Future<bool> pauseRecording() async {
    final bool didPause = await _channel.invokeMethod('pauseScreenRecording');
    return didPause;
  }

  static Future<bool> resumeRecording() async {
    final bool didResume = await _channel.invokeMethod('resumeScreenRecording');
    return didResume;
  }

  static Future<bool> get isRecording async {
    return await _channel.invokeMethod('isRecording');
  }

  static Future<bool> get hasBeenStarted async {
    return await _channel.invokeMethod('hasBeenStarted');
  }

  static startForgroundService() async {
    if (Platform.isAndroid) {
      await FlutterForegroundPlugin.setServiceMethodInterval(seconds: 5);
      await FlutterForegroundPlugin.setServiceMethod(globalForegroundService);
      await FlutterForegroundPlugin.startForegroundService(
        holdWakeLock: false,
        onStarted: () {
          print("Foreground on Started");
        },
        onStopped: () {
          print("Foreground on Stopped");
        },
        title: "Flutter Foreground Service",
        content: "This is Content",
        iconName: "ic_stat_hot_tub",
      );
    }
  }

  static void globalForegroundService() {
    print("Current datetime is ${DateTime.now()}");
  }
}
