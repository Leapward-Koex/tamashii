import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tamashii/services/gemini_nano_service.dart';

class GeminiNanoPage extends StatefulWidget {
  const GeminiNanoPage({super.key});

  @override
  State<GeminiNanoPage> createState() => _GeminiNanoPageState();
}

class _GeminiNanoPageState extends State<GeminiNanoPage> {
  final TextEditingController _controller = TextEditingController();

  String? _response;
  String? _error;
  bool _isLoading = false;

  bool get _isAndroidSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _response = null;
      _error = null;
    });

    try {
      final response = await GeminiNanoService.inferSeason(text);
      if (!mounted) {
        return;
      }
      setState(() {
        _response = response;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message ?? error.code;
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Gemini Nano is only wired up on Android builds in this demo.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Nano Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter a title and ask on-device Gemini Nano what season it belongs to.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. Frieren Season 2 or Attack on Titan part 3',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isAndroidSupported && !_isLoading ? _submit : null,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Ask Gemini Nano'),
            ),
            const SizedBox(height: 12),
            Text(
              _isAndroidSupported
                  ? 'This demo uses the Android on-device Gemini Nano path.'
                  : 'This demo page is disabled outside Android builds.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_response != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(_response!),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
