import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/refresh_notifier.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _violationDetected = false;
  String? _vehicleNumber;
  bool? _helmetPresent;
  String? _lastResult;
  final _plateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras!.first,
          ResolutionPreset.medium,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await _controller!.initialize();
        if (mounted) setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isInitialized = false);
    }
  }

  Future<void> _captureAndDetect() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);
    _lastResult = null;

    try {
      final image = await _controller!.takePicture();
      final file = File(image.path);

      final api = context.read<ApiService>();
      final vn = _plateController.text.trim().isNotEmpty ? _plateController.text.trim() : null;
      final result = await api.detectViolation(file, cameraLocation: 'Mobile Camera', vehicleNumber: vn);

      if (mounted) {
        setState(() => _isProcessing = false);
        if (result == null) {
          setState(() {
            _violationDetected = false;
            _lastResult = 'No response from server';
          });
          return;
        }
        if (result.containsKey('error')) {
          setState(() {
            _violationDetected = false;
            _lastResult = 'Error: ${result['error']}';
          });
          return;
        }

        final vehicle = result['vehicle_number']?.toString() ?? 'Unknown';
        final helmetPresent = result['helmet_present'];

        setState(() {
          _vehicleNumber = vehicle;
          _helmetPresent = helmetPresent is bool ? helmetPresent : null;
          _violationDetected = result['violation_detected'] == true;
          final helmetText = _helmetPresent == true
              ? 'Helmet: Yes'
              : (_helmetPresent == false ? 'Helmet: No' : 'Helmet: Unknown');
          _lastResult = 'Vehicle: $_vehicleNumber\n$helmetText';
        });

        if (result['violation_detected'] == true) {
          context.read<RefreshNotifier>().notifyDataChanged();
          _showViolationRecordDialog(context, result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _violationDetected = false;
          _lastResult = 'Error: $e';
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null || !mounted) return;

    setState(() => _isProcessing = true);
    _lastResult = null;

    try {
      final api = context.read<ApiService>();
      final vn = _plateController.text.trim().isNotEmpty ? _plateController.text.trim() : null;
      final result = await api.detectViolation(File(xfile.path), cameraLocation: 'Mobile Gallery', vehicleNumber: vn);

      if (mounted) {
        setState(() => _isProcessing = false);
        if (result == null) {
          setState(() {
            _violationDetected = false;
            _lastResult = 'No response from server';
          });
          return;
        }
        if (result.containsKey('error')) {
          setState(() {
            _violationDetected = false;
            _lastResult = 'Error: ${result['error']}';
          });
          return;
        }

        final vehicle = result['vehicle_number']?.toString() ?? 'Unknown';
        final helmetPresent = result['helmet_present'];

        setState(() {
          _vehicleNumber = vehicle;
          _helmetPresent = helmetPresent is bool ? helmetPresent : null;
          _violationDetected = result['violation_detected'] == true;
          final helmetText = _helmetPresent == true
              ? 'Helmet: Yes'
              : (_helmetPresent == false ? 'Helmet: No' : 'Helmet: Unknown');
          _lastResult = 'Vehicle: $_vehicleNumber\n$helmetText';
        });

        if (result['violation_detected'] == true) {
          context.read<RefreshNotifier>().notifyDataChanged();
          _showViolationRecordDialog(context, result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _violationDetected = false;
          _lastResult = 'Error: $e';
        });
      }
    }
  }

  void _showViolationRecordDialog(BuildContext context, Map<String, dynamic> result) {
    final vehicle = result['vehicle_number'] ?? 'Unknown';
    final fine = result['violation']?['fine_amount'] ?? 500;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 8),
            const Text('Violation Record'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Helmet not detected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                  const SizedBox(height: 8),
                  Text('Fine has been issued: ₹$fine', style: TextStyle(fontSize: 15, color: Colors.red.shade800)),
                  const SizedBox(height: 6),
                  Text('Vehicle: $vehicle', style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Record saved. Check Violations tab for details.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Detection'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _isInitialized && _controller != null
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _plateController,
                    decoration: InputDecoration(
                      hintText: 'AP03 BR4545',
                      labelText: 'Plate (enter full number if OCR shows partial)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.amber.shade50,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.previewSize!.height,
                          height: _controller!.value.previewSize!.width,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_lastResult != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: _violationDetected ? Colors.red.shade100 : Colors.green.shade100,
                    child: Text(
                      _lastResult!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _violationDetected ? Colors.red.shade900 : Colors.green.shade900,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton.filled(
                        onPressed: _isProcessing ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        iconSize: 40,
                      ),
                      GestureDetector(
                        onTap: _isProcessing ? null : _captureAndDetect,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isProcessing ? Colors.grey : Theme.of(context).colorScheme.primary,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: _isProcessing
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing camera...'),
                ],
              ),
            ),
    );
  }
}
