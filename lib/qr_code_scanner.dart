import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef void QRViewCreatedCallback(QRViewController controller);

const LIBRARY_ID = 'net.touchcapture.qr.flutterqr';

class QRView extends StatefulWidget {
  const QRView({
    @required Key key,
    @required this.onQRViewCreated,
    @required this.permissionStreamSink,
    this.overlay,
  })  : assert(key != null),
        assert(onQRViewCreated != null),
        assert(permissionStreamSink != null),
        super(key: key);

  final QRViewCreatedCallback onQRViewCreated;
  final StreamSink<bool> permissionStreamSink;
  final ShapeBorder overlay;

  @override
  State<StatefulWidget> createState() => _QRViewState();
}

class _QRViewState extends State<QRView> {
  MethodChannel permissionChannel;

  static const cameraPermission = 'cameraPermission';
  static const permissionGranted = 'granted';

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _getPlatformQrView(),
      widget.overlay != null
          ? Container(decoration: ShapeDecoration(shape: widget.overlay))
          : Container()
    ]);
  }

  Widget _platformQrView;

  Widget _getPlatformQrView() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_platformQrView == null) {
          _platformQrView = AndroidView(
              viewType: '$LIBRARY_ID/qrview',
              onPlatformViewCreated: _onPlatformViewCreated);
          return _platformQrView;
        } else {
          return _platformQrView;
        }
        break;
      case TargetPlatform.iOS:
        if (_platformQrView == null) {
          _platformQrView = UiKitView(
              viewType: '$LIBRARY_ID/qrview',
              onPlatformViewCreated: _onPlatformViewCreated,
              creationParams: _CreationParams.fromWidget(0, 0).toMap(),
              creationParamsCodec: StandardMessageCodec());
          return _platformQrView;
        } else {
          return _platformQrView;
        }
        break;
      default:
        throw UnsupportedError(
            "Trying to use the default webview implementation for $defaultTargetPlatform but there isn't a default one");
    }
  }

  void _onPlatformViewCreated(int id) {
    if (widget.onQRViewCreated == null) {
      return;
    }
    widget.onQRViewCreated(QRViewController._(id, widget.key));
    permissionChannel = MethodChannel('$LIBRARY_ID/permission');
    permissionChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == cameraPermission) {
        if (call.arguments != null) {
          final isPermissionGranted = call.arguments == permissionGranted;
          widget.permissionStreamSink.add(isPermissionGranted);
        }
      }
    });
  }
}

class _CreationParams {
  _CreationParams({this.width, this.height});

  static _CreationParams fromWidget(double width, double height) {
    return _CreationParams(
      width: width,
      height: height,
    );
  }

  final double width;
  final double height;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'width': width, 'height': height};
  }
}

class QRViewController {
  static const scanMethodCall = "onRecognizeQR";

  final MethodChannel _channel;

  StreamController<String> _scanUpdateController = StreamController<String>();

  Stream<String> get scannedDataStream => _scanUpdateController.stream;

  QRViewController._(int id, GlobalKey qrKey)
      : _channel = MethodChannel('$LIBRARY_ID/qrview_$id') {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final RenderBox renderBox = qrKey.currentContext.findRenderObject();
      _channel.invokeMethod("setDimensions",
          {"width": renderBox.size.width, "height": renderBox.size.height});
    }
    _channel.setMethodCallHandler(
      (MethodCall call) async {
        switch (call.method) {
          case scanMethodCall:
            {
              if (call.arguments != null) {
                _scanUpdateController.sink.add(call.arguments.toString());
              }
              break;
            }
        }
      },
    );
  }

  void flipCamera() {
    _channel.invokeMethod("flipCamera");
  }

  void toggleFlash() {
    _channel.invokeMethod("toggleFlash");
  }

  void pauseCamera() {
    _channel.invokeMethod("pauseCamera");
  }

  void resumeCamera() {
    _channel.invokeMethod("resumeCamera");
  }

  void dispose() {
    _scanUpdateController.close();
  }

  void openPermissionSettings() {
    _channel.invokeMethod("openPermissionSettings");
  }
}
