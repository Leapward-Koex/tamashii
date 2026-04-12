import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tamashii/providers/on_device_ai_provider.dart';
import 'package:tamashii/services/gemini_nano_prompts.dart';

class GeminiNanoPage extends ConsumerStatefulWidget {
  const GeminiNanoPage({super.key});

  @override
  ConsumerState<GeminiNanoPage> createState() => _GeminiNanoPageState();
}

class _GeminiNanoPageState extends ConsumerState<GeminiNanoPage> {
  final TextEditingController _controller = TextEditingController();

  String? _response;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _response = null;
      _error = null;
    });

    try {
      final generator = ref.read(onDeviceTextGeneratorProvider);
      final response = await generator.generateText(
        prompt: buildSeasonInferencePrompt(title),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _response = response.text;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message ?? error.code;
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
    final catalogAsync = ref.watch(onDeviceModelCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Nano Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          catalogAsync.when(
            data:
                (catalog) => Card(
                  child: ListTile(
                    title: const Text('Detected Prompt Model'),
                    subtitle: Text(catalog.activeModel ?? 'Unavailable'),
                  ),
                ),
            loading:
                () => const Card(
                  child: ListTile(
                    title: Text('Detected Prompt Model'),
                    subtitle: Text('Loading...'),
                  ),
                ),
            error:
                (error, _) => Card(
                  child: ListTile(
                    title: const Text('Detected Prompt Model'),
                    subtitle: Text('Error: $error'),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter a title and ask on-device AI what season it belongs to.',
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
            onPressed: !_isLoading ? _submit : null,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Ask Gemini Nano'),
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
    );
  }
}
