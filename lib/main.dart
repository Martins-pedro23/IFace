import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:iface_flutter/presentationals/widgets/face_detector/face_detector.dart';
import 'package:rxdart/subjects.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

void main() => runApp(IFace());

class IFace extends StatefulWidget {
  IFace({super.key});
  final faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
    ),
  );
  @override
  State<IFace> createState() => _IFaceState();
}

/* class FaceDetectorPainter extends CustomPainter {
  final Size absulteImageSize;
  final Face face;
  FaceDetectorPainter(this.absulteImageSize, this.face);

  @override
  void paint(Canvas canvas, Size size) {

    size = absulteImageSize;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    canvas.drawRect(
        Rect.fromLTRB(
            face.boundingBox.left,
            face.boundingBox.bottom,
            face.boundingBox.right,
            face.boundingBox.top),
        paint);
  }

  @override
  bool shouldRepaint(covariant FaceDetectorPainter oldDelegate) {
    return oldDelegate.absulteImageSize != absulteImageSize ||
        oldDelegate.face != face;
  }
} */

class _IFaceState extends State<IFace> {
  Face? _face;
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  final List<Widget> _serialData = [];

  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;

  final TextEditingController _textController = TextEditingController();

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
    }

    devices.forEach((device) {
      _ports.add(ListTile(
          leading: const Icon(Icons.usb),
          title: Text(device.productName!),
          subtitle: Text(device.manufacturerName!),
          trailing: ElevatedButton(
            child: Text(_device == device ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_device == device ? null : device).then((res) {
                _getPorts();
              });
            },
          )));
    });
  }

  @override
  void initState() {
    super.initState();

    UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();

    FaceTrackerBloc.main.face.listen((value) async {
      if (value!.headEulerAngleX! > 25 && _port != null) {
        await _port!.write(Uint8List.fromList("F\r\n".codeUnits));
      }
      if (value.headEulerAngleX! < -18 && _port != null) {
        await _port!.write(Uint8List.fromList("B\r\n".codeUnits));
      }
      if (value.headEulerAngleY! > 25 && _port != null) {
        await _port!.write(Uint8List.fromList("R\r\n".codeUnits));
      }
      if (value.headEulerAngleY! < -25 && _port != null) {
        await _port!.write(Uint8List.fromList("L\r\n".codeUnits));
      }

      setState(() {
        _face = value;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _connectTo(null);
  }

/*   Widget _buildFaceDetectorPainter() {
    if (_face == null) {
      return Container();
    }

    return CustomPaint(
      painter: FaceDetectorPainter(
        const Size(1080, 1920),
        _face!
      ),
    );
  } */

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.black, fontSize: 10, height: 1.5);
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'IFace',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: Material(
          child: Stack(
            children: [
              FaceDetectorView(
                onFaceDetected: (face) {
                  if (face.headEulerAngleX != null) {
                    FaceTrackerBloc.main.face.add(face);
                  }
                },
              ),
              /* _buildFaceDetectorPainter(), */
              Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(children: <Widget>[
                    Text(
                        _ports.isNotEmpty
                            ? "Available Serial Ports"
                            : "No serial devices available",
                        style: Theme.of(context).textTheme.titleLarge),
                    ..._ports,
                    Text('Status: $_status\n'),
                    Text('info: ${_port.toString()}\n'),
                    Text("Result Data",
                        style: Theme.of(context).textTheme.titleLarge),
                    ..._serialData,
                    Text("Face id: ${_face?.trackingId}", style: textStyle),
                    Text("X: ${_face?.headEulerAngleX}", style: textStyle),
                    Text("Y: ${_face?.headEulerAngleY}", style: textStyle),
                    Text("Z: ${_face?.headEulerAngleZ}", style: textStyle),
                    Text("Left eye open: ${_face?.leftEyeOpenProbability}",
                        style: textStyle),
                    Text("Right eye open: ${_face?.rightEyeOpenProbability}",
                        style: textStyle),
                    ListTile(
                      title: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Enviar Comando',
                        ),
                      ),
                      trailing: ElevatedButton(
                        child: const Text("Enviar"),
                        onPressed: _port == null
                            ? null
                            : () async {
                                if (_port == null) {
                                  return;
                                }
                                String data = "${_textController.text}\r\n";
                                await _port!
                                    .write(Uint8List.fromList(data.codeUnits));
                                _textController.text = "";
                              },
                      ),
                    ),
                    Text("Result Data",
                        style: Theme.of(context).textTheme.titleLarge),
                  ])),
            ],
          ),
        ));
  }
}

class FaceTrackerBloc {
  static FaceTrackerBloc main = FaceTrackerBloc();
  BehaviorSubject<Face?> face = BehaviorSubject<Face?>.seeded(null);
}
