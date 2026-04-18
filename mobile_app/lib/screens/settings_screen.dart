import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TextEditingController(
    text: ApiService.defaultBaseUrl,
  );
  bool _connected = false;
  String? _errorMessage;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final api = context.read<ApiService>();
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    if (mounted) setState(() {
      _checking = true;
      _errorMessage = null;
    });
    api.setBaseUrl(url);
    final result = await api.checkHealthWithError();
    if (mounted) {
      setState(() {
        _connected = result.success;
        _errorMessage = result.error;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'API Server URL',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'http://192.168.0.4:5001',
                border: const OutlineInputBorder(),
                suffixIcon: Icon(
                  _connected ? Icons.check_circle : Icons.error,
                  color: _connected ? Colors.green : Colors.red,
                ),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _checkConnection(),
            ),
            const SizedBox(height: 8),
            Text(
              'Use your PC IP:5001 (e.g. http://192.168.0.4:5001). Same WiFi required.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_connected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text('Connected', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checking ? null : _checkConnection,
              child: _checking
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
