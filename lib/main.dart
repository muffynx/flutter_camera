import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:html' as html;  //web support
import 'package:image_gallery_saver/image_gallery_saver.dart'; //  mobile support
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; 


List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error initializing camera: $e');
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<File> _capturedImages = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _capturedImages.isEmpty
          ? const Center(
              child: Text('Tap the button to take a picture!'),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _capturedImages.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageView(
                            imagePath: _capturedImages[index].path,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(_capturedImages[index]),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final XFile? capturedImage = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CameraScreen(cameras: cameras),
            ),
          );

          if (capturedImage != null) {
            setState(() {
              _capturedImages.add(File(capturedImage.path));
            });
          }
        },
        tooltip: 'Take a Picture',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget _buildImageWidget(File file) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4), 
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? Image.memory(
                    file.readAsBytesSync(), 
                    fit: BoxFit.cover,
                    width: 200,
                    height: 200,
                  )
                : Image.file(
                    file,
                    fit: BoxFit.cover,
                    width: 200,
                    height: 200,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Polaroid',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageView extends StatelessWidget {
  final String imagePath;

  const FullScreenImageView({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Photo View'),
      ),
      body: Center(
        child: kIsWeb
            ? Image.memory(
                File(imagePath).readAsBytesSync(),
                fit: BoxFit.contain,
              )
            : Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRearCameraSelected = true;

  @override
  void initState() {
    super.initState();
    _initCamera(widget.cameras[0]);
  }

  Future<void> _initCamera(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  Future<void> _saveImageToGallery(String imagePath) async {
    if (!kIsWeb) {
      try {
        final result = await ImageGallerySaver.saveFile(imagePath);
        print(result);
      } catch (e) {
        print('Error saving image to gallery: $e');
      }
    } else {
      // For web, create a download link
      final byteData = await File(imagePath).readAsBytes();
      final buffer = html.Blob([byteData]);
      final url = html.Url.createObjectUrlFromBlob(buffer);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'image.jpg')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _saveImageToDirectory(String imagePath) async {
    if (!kIsWeb) {
      try {
        final directory = await getExternalStorageDirectory();
        final newFile = await File(imagePath).copy('${directory?.path}/image.jpg');
        print('File saved at: ${newFile.path}');
      } catch (e) {
        print('Error saving image to directory: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Picture'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Expanded(child: CameraPreview(_controller)),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            heroTag: 'switchCamera',
            onPressed: () {
              setState(() {
                _isRearCameraSelected = !_isRearCameraSelected;
                int cameraIndex = _isRearCameraSelected ? 0 : 1;
                if (widget.cameras.length > cameraIndex) {
                  _initCamera(widget.cameras[cameraIndex]);
                }
              });
            },
            child: const Icon(Icons.flip_camera_ios),
          ),
          FloatingActionButton(
            heroTag: 'takePicture',
            onPressed: () async {
              try {
                await _initializeControllerFuture;
                final image = await _controller.takePicture();
                await _saveImageToGallery(image.path);
                await _saveImageToDirectory(image.path);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Picture saved to gallery!')),
                );
                Navigator.pop(context, image);
              } catch (e) {
                print('Error taking picture: $e');
              }
            },
            child: const Icon(Icons.camera),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
