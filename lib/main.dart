import 'dart:async';
import 'dart:typed_data';

import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:rxdart/subjects.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

import 'presentationals/widgets/face_detector/face_detector.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
    ),
  );
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Stack(
        children: [
          FaceDetectorView(
            onFaceDetected: (face) {
              if (face.headEulerAngleX != null) {
                FaceTrackerBloc.main.face.add(face);
              }
            },
          ),
          const IgnorePointer(child: TestRender()),
        ],
      ),
    );
  }
}

class TestRender extends StatefulWidget {
  const TestRender({
    super.key,
  });
  @override
  State<TestRender> createState() => _TestRenderState();
}

class _TestRenderState extends State<TestRender> {
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  List<Widget> _serialData = [];

  bool _isConnected = false;
  bool _isFaceDetected = false;
  FaceLandmark? _faceLandmark;
  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;
  Face? _face;
  TextEditingController _textController = TextEditingController();

  Future<bool> _connectTo(device) async {
    _serialData.clear();

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      setState(() {
        _status = "Disconnected";
      });
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      setState(() {
        _status = "Failed to open port";
      });
      return false;
    }
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
        9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      setState(() {
        _serialData.add(Text(line));
        if (_serialData.length > 20) {
          _serialData.removeAt(0);
        }
      });
    });

    setState(() {
      _status = "Connected";
    });
    return true;
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
      _isConnected = false;
    }
    print(devices);

    devices.forEach((device) {
      _connectTo(_device == device ? null : device).then((res) {
        _getPorts();
      });
    });

    if (!devices.isEmpty) {
      _isConnected = true;
    }
    setState(() {
      print(devices);
    });
  }

  @override
  void initState() {
    super.initState();
    FaceTrackerBloc.main.face.listen((value) {
      setState(() {
        _face = value;
      });
    });
    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
  }

  Widget _faceLandmarkTypeWidget() {
    List<Widget> widgets = [];
    int i = 0;
    if (_face?.landmarks == null) {
      return Container();
    }
    _face?.landmarks.values.forEach((element) {
      if (element != null) {
        widgets.add(Text('${_face?.landmarks.keys.elementAt(i).name}: ${element!.position.x.toString()}, ${element.position.y.toString()}',
          style: TextStyle(color: Colors.black, fontSize: 10)));
      }
      i++;
    });
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _faceContoursWidget() {
    List<Widget> widgets = [];
    int i = 0;
    if (_face?.contours == null) {
      return Container();
    }
    _face?.contours.values.forEach((element) {
      element!.points.forEach((element) {
        if (element != null){
          widgets.add(Text('${_face?.contours.keys.elementAt(i).name}: ${element.x.toString()}, ${element.y.toString()}',
            style: TextStyle(color: Colors.black, fontSize: 10)));
        }
      });
    });
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future:
            ObjParser().loadFromResources("assets/glasses/circle_glasses.obj"),
        builder: (context, snapshot) {
          return Container(
            height: 400,
            color: Colors.blue,
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  _isConnected == true
                      ? "Arduino Detectado"
                      : "Arduino não detectado",
                  style: TextStyle(color: Colors.black, fontSize: 20),
                ),
                Container(
                  color: Colors.blue,
                  height: 400,
                  alignment: Alignment.bottomCenter,
                  child: ListView(
                    children: [
                      Text("Face id: ${_face?.trackingId}",
                          style: TextStyle(color: Colors.black, fontSize: 15)),
                      Text("X: ${_face?.headEulerAngleX}",
                          style: TextStyle(color: Colors.black, fontSize: 15)),
                      Text("Y: ${_face?.headEulerAngleY}",
                          style: TextStyle(color: Colors.black, fontSize: 15)),
                      Text("Z: ${_face?.headEulerAngleZ}",
                          style: TextStyle(color: Colors.black, fontSize: 15)),
                      Text("Left eye: ${_face?.leftEyeOpenProbability}",
                          style: TextStyle(color: Colors.black, fontSize: 15)),
                      Text("Right eye: ${_face?.rightEyeOpenProbability}",
                          style: TextStyle(color: Colors.black, fontSize: 15)),
                      Text("smiling: ${_face?.smilingProbability}",
                          style: TextStyle(color: Colors.black, fontSize: 15)),
                      _faceLandmarkTypeWidget(),
                      _faceContoursWidget()
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }
}

class FaceTrackerBloc {
  static FaceTrackerBloc main = FaceTrackerBloc();
  BehaviorSubject<Face?> face = BehaviorSubject<Face?>.seeded(null);
}
