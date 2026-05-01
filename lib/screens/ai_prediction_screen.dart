import 'dart:typed_data';

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/services/ai_prediction_service.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class AiPredictionScreen extends ConsumerStatefulWidget {
  const AiPredictionScreen({super.key});

  @override
  ConsumerState<AiPredictionScreen> createState() => _AiPredictionScreenState();
}

class _AiPredictionScreenState extends ConsumerState<AiPredictionScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _fileName;
  AiPredictionResult? _result;
  String? _error;
  bool _isLoading = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _fileName = file.name.isEmpty ? 'report.jpg' : file.name;
        _result = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read selected image.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image selection failed: $e')));
    }
  }

  Future<void> _runPrediction() async {
    final bytes = _imageBytes;
    if (bytes == null) {
      setState(() => _error = 'Please choose a blood report image first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final service = ref.read(aiPredictionServiceProvider);
      final prediction = await service.predictImage(
        imageBytes: bytes,
        fileName: _fileName ?? 'report.jpg',
      );
      if (!mounted) return;
      setState(() => _result = prediction);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Eligibility Check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Upload a CBC report image to run AI prediction.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(
                child: Text('No image selected', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Camera'),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _runPrediction,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_isLoading ? 'Analyzing...' : 'Analyze'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 18),
            _ResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final AiPredictionResult result;

  @override
  Widget build(BuildContext context) {
    final isEligible = result.eligible;
    final color = isEligible ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Result: ${result.result}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text('Confidence: ${result.confidence.toStringAsFixed(2)}%'),
          Text('Raw probability: ${result.rawProbability.toStringAsFixed(4)}'),
          const SizedBox(height: 10),
          Text(
            'Predicted blood parameters',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...result.regressionDenormalized.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${entry.key}: ${entry.value}'),
            ),
          ),
          if (result.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Reasons',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...result.reasons.map((r) => Text('• $r')),
          ],
        ],
      ),
    );
  }
}
