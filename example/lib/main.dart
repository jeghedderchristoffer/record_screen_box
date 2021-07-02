import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record_screen_box/record_screen_box.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    [
      Permission.photos,
      Permission.storage,
      Permission.microphone,
    ].request();
  }

  void startRecording() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();

    bool result = await RecordScreenBox.startRecording(
      'test',
      appDocDir.path,
    );
    print("START RESULT: " + result.toString());
    setState(() {}); // UPDATE UI
  }

  void stopRecording() async {
    String result = await RecordScreenBox.stopRecording();
    print("STOP RESULT: " + result.toString());
    setState(() {}); // UPDATE UI

    final openResult = await OpenFile.open(result);
    print(openResult.message);
  }

  void pauseRecording() async {
    bool result = await RecordScreenBox.pauseRecording();
    print("PAUSE RESULT: " + result.toString());
    setState(() {}); // UPDATE UI
  }

  void resumeRecording() async {
    bool result = await RecordScreenBox.resumeRecording();
    print("RESUME RESULT: " + result.toString());
    setState(() {}); // UPDATE UI
  }

  @override
  Widget build(BuildContext context) {
    Widget isRecording = FutureBuilder(
      future: RecordScreenBox.isRecording,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text("IS RECORDING: " + snapshot.data.toString());
        }
        return Text("IS RECORDING: LOADING...");
      },
    );

    Widget hasBeenStarted = FutureBuilder(
      future: RecordScreenBox.hasBeenStarted,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text("HAS BEEN STARTED: " + snapshot.data.toString());
        }
        return Text("HAS BEEN STARTED: LOADING...");
      },
    );

    Widget buttonStart = TextButton(
      onPressed: () => startRecording(),
      child: Text("START RECORDING"),
    );

    Widget buttonStop = TextButton(
      onPressed: () => stopRecording(),
      child: Text("STOP RECORDING"),
    );

    Widget buttonPause = TextButton(
      onPressed: () => pauseRecording(),
      child: Text("PAUSE RECORDING"),
    );

    Widget buttonResume = TextButton(
      onPressed: () => resumeRecording(),
      child: Text("RESUME RECORDING"),
    );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Screen recorder box'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isRecording,
              hasBeenStarted,
              buttonStart,
              buttonStop,
              buttonPause,
              buttonResume,
            ],
          ),
        ),
      ),
    );
  }
}
