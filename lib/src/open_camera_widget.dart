import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:open_camera/src/preview_photo.dart';
import 'package:open_camera/src/preview_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

//
enum CameraMode { Photo, Video }

class CameraSettings {
  //
  final int limitRecord;
  final bool useCompression;
  final bool forceDeviceOrientation;
  final ResolutionPreset resolutionPreset;
  final List<NativeDeviceOrientation> deviceOrientation;

  //
  CameraSettings({
    this.limitRecord = -1,
    this.deviceOrientation,
    this.useCompression = false,
    this.resolutionPreset = ResolutionPreset.medium,
    this.forceDeviceOrientation = false,
  });
}

Future<File> openCamera(
  BuildContext buildContext,
  CameraMode cameraMode, {
  CameraSettings cameraSettings,
}) async {
  //
  try {
    //
    await PermissionHandler().requestPermissions(
      [
        PermissionGroup.camera,
        PermissionGroup.microphone,
        PermissionGroup.storage,
        PermissionGroup.photos
      ],
    );
    //
    List<CameraDescription> cameras = await availableCameras();
    //
    var permissionCamera =
        await PermissionHandler().checkPermissionStatus(PermissionGroup.camera);
    var permissionMicrophone = await PermissionHandler()
        .checkPermissionStatus(PermissionGroup.microphone);
    var permissionStorage = await PermissionHandler()
        .checkPermissionStatus(PermissionGroup.storage);
    var permissionPhotos =
        await PermissionHandler().checkPermissionStatus(PermissionGroup.photos);
    //
    if (permissionCamera == PermissionStatus.granted &&
        permissionMicrophone == PermissionStatus.granted &&
        permissionStorage == PermissionStatus.granted &&
        permissionPhotos == PermissionStatus.granted) {
      //
      final resultCamera = await Navigator.push(
        buildContext,
        MaterialPageRoute(
          builder: (context) {
            return OpenCamera(
              cameras,
              cameraMode,
              cameraSettings ?? CameraSettings(),
            );
          },
        ),
      );
      //
      return resultCamera != null ? File(resultCamera) : null;
    }
    return null;
  } catch (_) {
    rethrow;
  }
}

class OpenCamera extends StatefulWidget {
  //
  final CameraMode cameraMode;
  final CameraSettings cameraOptions;
  final List<CameraDescription> cameraDescription;

  //
  OpenCamera(
    this.cameraDescription,
    this.cameraMode,
    this.cameraOptions,
  );

  //
  @override
  _OpenCameraState createState() => _OpenCameraState(
        this.cameraDescription,
        this.cameraMode,
        this.cameraOptions,
      );
}

class _OpenCameraState extends State<OpenCamera> with WidgetsBindingObserver {
  //
  final MethodChannel _channel = const MethodChannel('open_camera');
  //
  Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  //
  bool _initRecord = false;
  String _timeRecord = "00:00";
  String _fileLocation;

  //
  CameraController controller;
  CameraDescription cameraSelected;

  //
  final CameraMode cameraMode;
  final CameraSettings cameraSettings;
  final List<CameraDescription> cameraDescription;

  //
  _OpenCameraState(
    this.cameraDescription,
    this.cameraMode,
    this.cameraSettings,
  );

  //
  @override
  void initState() {
    //
    super.initState();
    //
    WidgetsBinding.instance.addObserver(this);
    this.cameraSelected = cameraDescription.first;
    //
    _initCamera();
  }

  //
  void _initCamera() {
    //
    controller = CameraController(
      this.cameraSelected,
      this.cameraSettings.resolutionPreset,
      enableAudio: true,
    );
    //
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  //
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  //
  @override
  void dispose() {
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  //
  @override
  Widget build(BuildContext context) {
    //
    if (!controller.value.isInitialized) {
      return Container();
    }
    //
    return NativeDeviceOrientationReader(
      builder: (BuildContext context) {
        //
        final size = MediaQuery.of(context).size;
        final orientation = NativeDeviceOrientationReader.orientation(context);
        //
        final _deviceOrientationExist = this
                .cameraSettings
                ?.deviceOrientation
                ?.firstWhere(
                    (deviceOrientation) => deviceOrientation == orientation)
                ?.index ??
            -1;
        //
        bool _wrongOrientation = (this.cameraSettings.forceDeviceOrientation &&
            _deviceOrientationExist > -1);
        //
        if (_wrongOrientation) {
          return FutureBuilder<Widget>(
            future: _invalidOrientation(),
            builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return snapshot.data;
              } else {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          );
        }
        //
        return Scaffold(
          body: SizedBox(
            height: size.height,
            width: size.width,
            child: SafeArea(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: Stack(
                  children: <Widget>[
                    _addScreen(context),
                    _addCameraTools(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      useSensor: true,
    );
  }

  //
  Future<String> _takeCamera() async {
    //
    if (!controller.value.isInitialized) {
      return null;
    }
    //
    final Directory dirApp = await getExternalStorageDirectory();
    //
    final String dirPathApp = this.cameraMode == CameraMode.Photo
        ? '${dirApp.path}/photos'
        : '${dirApp.path}/videos';
    //
    final String filePathApp = this.cameraMode == CameraMode.Photo
        ? '$dirPathApp/${_timestamp()}.jpg'
        : '$dirPathApp/${_timestamp()}.mp4';
    //
    await Directory(dirPathApp).create(recursive: true);
    //
    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    //
    try {
      //
      if (this.cameraMode == CameraMode.Photo) {
        await controller.takePicture(filePathApp);
      } else if (this.cameraMode == CameraMode.Video) {
        await controller.startVideoRecording(filePathApp);
      } else {
        return null;
      }
    } on CameraException catch (_) {
      return null;
    }
    return filePathApp;
  }

  //
  Widget _addScreen(BuildContext context) {
    //
    final size = MediaQuery.of(context).size;
    //
    return Container(
      decoration: _screenBorderDecoration(),
      child: Stack(
        children: <Widget>[
          ClipRect(
            child: Transform.scale(
              scale: controller.value.aspectRatio / size.aspectRatio,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
          _addTimeCount(context)
        ],
      ),
    );
  }

  //
  Widget _addTimeCount(BuildContext context) {
    try {
      //
      NativeDeviceOrientation orientation =
          NativeDeviceOrientationReader.orientation(context);
      //
      if (orientation == NativeDeviceOrientation.portraitUp ||
          orientation == NativeDeviceOrientation.portraitDown) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _timeWidget(_timeRecord),
          ],
        );
      } else {
        return Row(
          children: <Widget>[
            //
            orientation == NativeDeviceOrientation.landscapeRight
                ? RotatedBox(
                    quarterTurns: 3,
                    child: _timeWidget(_timeRecord),
                  )
                : Container(),
            //
            Expanded(
                child: Divider(
              color: Colors.transparent,
            )),
            //
            orientation == NativeDeviceOrientation.landscapeLeft
                ? RotatedBox(
                    quarterTurns: 1,
                    child: _timeWidget(_timeRecord),
                  )
                : Container(),
          ],
        );
      }
    } catch (_) {
      rethrow;
    }
  }

  //
  Widget _addCameraTools(BuildContext context) {
    //
    final size = MediaQuery.of(context).size;
    return Positioned(
      bottom: 0,
      child: Opacity(
        opacity: 1,
        child: Container(
          width: size.width,
          height: 130.0,
          decoration: BoxDecoration(
            color: Colors.black45,
          ),
          child: Row(
            children: <Widget>[
              _addSwitchCamera(context),
              _addCentralButton(this.cameraMode, context),
              _addThumb(context),
            ],
          ),
        ),
      ),
    );
  }

  //
  Widget _addCentralButton(CameraMode mode, BuildContext context) {
    if (mode == CameraMode.Photo) {
      return _addPhotoButton(context);
    } else {
      return _addRecordButton(context);
    }
  }

  //
  Widget _addRecordButton(BuildContext context) {
    return Expanded(
      child: SizedBox(
        width: 80.0,
        height: 80.0,
        child: FloatingActionButton(
          heroTag: "recordButton",
          backgroundColor: Colors.white,
          child: Icon(
            _initRecord ? Icons.stop : Icons.fiber_manual_record,
            size: 70.0,
            color: Colors.grey,
          ),
          onPressed: () async {
            await _recordButtonPressed(context);
          },
        ),
      ),
    );
  }

  //
  Widget _addPhotoButton(BuildContext context) {
    return Expanded(
      child: SizedBox(
        width: 80.0,
        height: 80.0,
        child: FloatingActionButton(
          heroTag: "photoButton",
          backgroundColor: Colors.white,
          child: Icon(
            Icons.camera,
            size: 70.0,
            color: Colors.grey,
          ),
          onPressed: () async {
            await _photoButtonPressed(context);
          },
        ),
      ),
    );
  }

  //
  Widget _addThumb(BuildContext context) {
    int turns = _turnsDeviceOrientation(context);
    return Expanded(
      child: RotatedBox(
        quarterTurns: turns,
        child: SizedBox(
          width: 80.0,
          height: 80.0,
          child: Container(),
        ),
      ),
    );
  }

  //
  Widget _addSwitchCamera(BuildContext context) {
    //
    int turns = _turnsDeviceOrientation(context);
    return Expanded(
      child: RotatedBox(
        quarterTurns: turns,
        child: SizedBox(
          width: 40.0,
          height: 40.0,
          child: !_initRecord
              ? FloatingActionButton(
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.switch_camera,
                    size: 30.0,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    if (this.cameraSelected.lensDirection ==
                        CameraLensDirection.front) {
                      this.cameraSelected = this.cameraDescription.firstWhere(
                          (cam) =>
                              cam.lensDirection == CameraLensDirection.back);
                    } else {
                      this.cameraSelected = this.cameraDescription.firstWhere(
                          (cam) =>
                              cam.lensDirection == CameraLensDirection.front);
                    }
                    //
                    _initCamera();
                  },
                )
              : Container(),
        ),
      ),
    );
  }

  //
  Future<Widget> _invalidOrientation() async {
    //
    if (_initRecord) {
      _initRecord = false;
      await controller.stopVideoRecording();
    }
    //
    return Container(
      color: Colors.red,
    );
  }

  //
  int _turnsDeviceOrientation(BuildContext context) {
    //
    NativeDeviceOrientation orientation =
        NativeDeviceOrientationReader.orientation(context);
    //
    int turns;
    switch (orientation) {
      case NativeDeviceOrientation.landscapeLeft:
        turns = -1;
        break;
      case NativeDeviceOrientation.landscapeRight:
        turns = 1;
        break;
      case NativeDeviceOrientation.portraitDown:
        turns = 2;
        break;
      default:
        turns = 0;
        break;
    }

    return turns;
  }

  //
  Widget _timeWidget(String timeRecord) {
    try {
      return _initRecord
          ? Padding(
              padding: EdgeInsets.all(10),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.all(
                      Radius.circular(8),
                    ),
                  ),
                  padding: EdgeInsets.all(6),
                  child: SizedBox(
                    width: 80,
                    child: Center(
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.fiber_manual_record,
                            color: Colors.red,
                          ),
                          Text(
                            timeRecord,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Container();
    } catch (_) {
      rethrow;
    }
  }

  //
  String _timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  //
  BoxDecoration _screenBorderDecoration() {
    if (_initRecord) {
      return BoxDecoration(
        border: Border.all(
          color: Colors.red,
          style: BorderStyle.solid,
          width: 3,
        ),
      );
    } else {
      return BoxDecoration();
    }
  }

  //------------------------
  // EVENTS
  //------------------------
  //
  Future _recordButtonPressed(BuildContext context) async {
    //
    if (_initRecord) {
      _stopVideoRecording();
    } else {
      _initializeChronometer();
      _fileLocation = await _takeCamera();
    }
  }

  //
  Future _photoButtonPressed(BuildContext context) async {
    _fileLocation = await _takeCamera();
    //
    String fileLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return PreviewPhoto(_fileLocation);
        },
      ),
    );
    //
    Navigator.pop(context, fileLocation);
  }

  //
  void _initializeChronometer() {
    //
    Timer.periodic(Duration(milliseconds: 100), (Timer timer) {
      //
      setState(() {
        _initRecord = controller.value.isRecordingVideo;
      });

      if (!_initRecord) {
        return;
      } else if (_initRecord && timer.isActive) {
        timer.cancel();
      }
      //
      Timer.periodic(Duration(seconds: 1), (Timer timer2) {
        //
        setState(() {
          _initRecord = controller.value.isRecordingVideo;
        });
        //
        if (!_initRecord && timer2.isActive) {
          timer2.cancel();
          return;
        }
        //
        if (_initRecord) {
          setState(() {
            //
            _timeRecord = formatRecordingTime(timer2.tick);
            //
            if (this.cameraSettings.limitRecord > -1 &&
                timer2.tick >= this.cameraSettings.limitRecord) {
              timer2.cancel();
              _stopVideoRecording();
            }
          });
        } else {
          setState(() {
            timer2.cancel();
            _timeRecord = "00:00";
          });
        }
      });
    });
  }

  //
  void _stopVideoRecording() async {
    //
    _initRecord = false;
    _timeRecord = "00:00";
    await controller.stopVideoRecording();
    //
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return VideoPreview(_fileLocation, this.cameraSettings);
        },
      ),
    );
    //
    if (result == null) {
      await File(_fileLocation).delete(recursive: true);
      return;
    }
    //
    Navigator.pop(context, result);
  }
}