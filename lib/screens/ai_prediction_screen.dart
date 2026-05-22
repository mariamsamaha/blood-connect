import 'dart:convert';
import 'dart:typed_data';

import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/services/ai_assistant_service.dart';
import 'package:bloodconnect/services/ai_prediction_service.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AiPredictionScreen extends ConsumerStatefulWidget {
  const AiPredictionScreen({super.key});

  @override
  ConsumerState<AiPredictionScreen> createState() => _AiPredictionScreenState();
}

class _AiPredictionScreenState extends ConsumerState<AiPredictionScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _fileName;
  AiPredictionResult? _result;
  String? _error;
  bool _isLoading = false;
  bool _serviceConnected = false;
  String? _serviceStatus;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  final List<_ChatMsg> _chatMessages = [];
  bool _chatLoading = false;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkService();
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _checkService() async {
    try {
      final service = ref.read(aiPredictionServiceProvider);
      final baseUrl = service.resolveBaseUrlForDebug();
      final healthUri = Uri.parse('$baseUrl/health');
      final response = await http.get(healthUri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final health = jsonDecode(response.body);
        if (health['model_loaded'] == true) {
          setState(() {
            _serviceConnected = true;
            _serviceStatus = 'AI Service connected (${health['device']})';
          });
        }
      }
    } catch (e) {
      setState(() {
        _serviceConnected = false;
        _serviceStatus = 'AI Service unavailable - check Python server';
      });
    }
  }

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
        _chatMessages.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read selected image.');
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
      _chatMessages.clear();
    });

    try {
      final service = ref.read(aiPredictionServiceProvider);
      final prediction = await service.predictImage(
        imageBytes: bytes,
        fileName: _fileName ?? 'report.jpg',
      );
      if (!mounted) return;
      setState(() {
        _result = prediction;
        _serviceConnected = true;
      });
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = errorMsg;
        if (errorMsg.contains('Cannot connect') || errorMsg.contains('not responding')) {
          _serviceConnected = false;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _result == null) return;

    setState(() {
      _chatMessages.add(_ChatMsg(role: 'user', content: text));
      _chatLoading = true;
      _chatController.clear();
    });
    _scrollToBottom();

    try {
      final assistantService = const AiAssistantService();
      final messages = _chatMessages
          .map((m) => ChatMessage(role: m.role, content: m.content))
          .toList();

      final donorData = {
        ..._result!.regressionDenormalized,
        'reasons': _result!.reasons,
        'confidence': _result!.confidence,
      };

      final reply = await assistantService.sendChat(
        messages: messages,
        donorData: donorData,
      );

      if (!mounted) return;
      setState(() {
        _chatMessages.add(_ChatMsg(role: 'assistant', content: reply));
        _chatLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chatMessages.add(_ChatMsg(
          role: 'assistant',
          content: 'Sorry, I could not respond at this moment. Please try again.',
        ));
        _chatLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Eligibility Check'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (_serviceConnected ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    _serviceConnected ? Icons.check_circle : Icons.error,
                    color: _serviceConnected ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _serviceStatus ?? 'Checking...',
                  style: TextStyle(
                    color: _serviceConnected ? Colors.green : Colors.orange,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderBanner(),
                const SizedBox(height: 20),
                _buildImageArea(),
                const SizedBox(height: 16),
                _buildActionButtons(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _ResultCard(result: _result!),
                ],
                if (_result != null && !_result!.eligible) ...[
                  const SizedBox(height: 24),
                  _buildAssistantSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryRed.withValues(alpha: 0.1),
            AppColors.primaryRed.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.primary,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Know Before You Give',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload your blood report and let AI check if you\'re ready to donate safely.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildActionChip(
          icon: Icons.photo_library_rounded,
          label: 'Gallery',
          onTap: _isLoading ? null : () => _pick(ImageSource.gallery),
        ),
        _buildActionChip(
          icon: Icons.camera_alt_rounded,
          label: 'Camera',
          onTap: _isLoading ? null : () => _pick(ImageSource.camera),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _runPrediction,
          icon: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(_isLoading ? 'Analyzing...' : 'Analyze'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        _buildActionChip(
          icon: Icons.refresh,
          label: 'Reconnect',
          onTap: _isLoading ? null : _checkService,
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: onTap == null ? AppColors.textTertiary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis Failed',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea() {
    if (_imageBytes == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).cardColor,
              AppColors.primaryRed.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.divider,
            width: 1.5,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryRed.withValues(alpha: 0.08),
                      AppColors.primaryRed.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.primaryRed.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 40,
                  color: AppColors.primaryRed.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No image selected',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap Gallery or Camera to upload your blood report',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        children: [
          Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover, width: double.infinity),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => setState(() {
                  _imageBytes = null;
                  _result = null;
                  _error = null;
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Container(color: Colors.black.withValues(alpha: 0.2)),
                        Positioned(
                          top: _scanAnimation.value * (220 - 3),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withValues(alpha: 0.8),
                                  blurRadius: 12,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Container(color: AppColors.primaryRed.withValues(alpha: 0.9)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssistantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: AppShadows.glowRed,
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'AI Assistant',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (_chatMessages.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _chatMessages.clear()),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 340,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Expanded(
                child: _chatMessages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryRed.withValues(alpha: 0.08),
                                      AppColors.primaryRed.withValues(alpha: 0.02),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                  border: Border.all(
                                    color: AppColors.primaryRed.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Icon(
                                  Icons.psychology_outlined,
                                  size: 40,
                                  color: AppColors.primaryRed.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ask me anything about your results',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'I can explain your blood values and give tips to help you get ready for donation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _chatScroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, i) {
                          final msg = _chatMessages[i];
                          final isUser = msg.role == 'user';
                          return _ChatBubble(message: msg, isUser: isUser);
                        },
                      ),
              ),
              if (_chatLoading)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      const Text('Thinking...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              _ChatInputBar(
                controller: _chatController,
                onSend: _sendMessage,
                disabled: _chatLoading,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatMsg {
  const _ChatMsg({required this.role, required this.content});
  final String role;
  final String content;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isUser});
  final _ChatMsg message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8, top: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 14, color: Colors.white),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? AppGradients.primary
                        : LinearGradient(
                            colors: [
                              AppColors.background,
                              AppColors.background,
                            ],
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isUser ? 12 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 12),
                    ),
                    boxShadow: isUser ? AppShadows.primary : AppShadows.card,
                  ),
                  child: isUser
                      ? Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 14))
                      : MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.5),
                            strong: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            listBullet: TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                            blockquote: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: AppColors.primaryRed.withValues(alpha: 0.3),
                                  width: 3,
                                ),
                              ),
                            ),
                            code: TextStyle(
                              backgroundColor: Colors.grey.shade200,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          shrinkWrap: true,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatefulWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    this.disabled = false,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool disabled;

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  late bool _hasText;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_ChatInputBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _onTextChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final empty = widget.controller.text.trim().isEmpty;
    if (empty == _hasText) return;
    setState(() => _hasText = !empty);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !widget.disabled && _hasText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              enabled: !widget.disabled,
              decoration: InputDecoration(
                hintText: 'Ask about your results...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => widget.onSend(),
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: AppAnimations.fast,
            decoration: BoxDecoration(
              gradient: canSend ? AppGradients.primary : null,
              color: canSend ? null : AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              boxShadow: canSend ? AppShadows.glowRed : null,
            ),
            child: IconButton(
              onPressed: canSend ? widget.onSend : null,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final AiPredictionResult result;

  List<_FlaggedValue> _getFlaggedValues() {
    final flagged = <_FlaggedValue>[];
    for (final entry in _thresholds.entries) {
      final param = entry.key;
      final (minVal, maxVal, unit, label) = entry.value;
      final value = result.regressionDenormalized[param];
      if (value == null) continue;
      final numValue = (value is num) ? value.toDouble() : double.tryParse(value.toString());
      if (numValue == null) continue;

      String? status;
      if (minVal != null && numValue < minVal) {
        status = 'Below normal';
      } else if (maxVal != null && numValue > maxVal) {
        status = 'Above normal';
      }

      if (status != null) {
        final rangeStr = maxVal != null && minVal != null
            ? '$minVal - $maxVal'
            : minVal != null
                ? '${minVal}+'
                : '${maxVal}!';
        flagged.add(_FlaggedValue(
          name: label,
          value: numValue.toStringAsFixed(1),
          unit: unit,
          range: rangeStr,
          status: status,
        ));
      }
    }
    return flagged;
  }

  @override
  Widget build(BuildContext context) {
    final isEligible = result.eligible;
    final flagged = _getFlaggedValues();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isEligible)
          _buildEligibleBanner()
        else
          _buildDeferredBanner(),
        if (result.reasons.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildReasonsCard(isEligible),
        ],
        if (flagged.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildFlaggedSection(context, flagged),
        ],
      ],
    );
  }

  Widget _buildEligibleBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.12),
            AppColors.success.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppGradients.success,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Eligible to Donate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${result.confidence.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  '${result.confidence.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeferredBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: 0.12),
            AppColors.warning.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppGradients.warning,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Donation Temporarily Deferred',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${result.confidence.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  '${result.confidence.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonsCard(bool isEligible) {
    final accent = isEligible ? AppColors.success : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEligible
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isEligible
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.warning.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEligible ? Icons.check_circle_outline : Icons.info_outline_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                isEligible ? 'Assessment Summary' : 'Why?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...result.reasons.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlaggedSection(BuildContext context, List<_FlaggedValue> flagged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Icon(Icons.flag_outlined, size: 16, color: AppColors.warning),
            ),
            const SizedBox(width: 10),
            Text(
              'Flagged Values',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...flagged.map((f) => _FlaggedValueTile(flagged: f)),
      ],
    );
  }
}

class _FlaggedValue {
  const _FlaggedValue({
    required this.name,
    required this.value,
    required this.unit,
    required this.range,
    required this.status,
  });

  final String name;
  final String value;
  final String unit;
  final String range;
  final String status;
}

const Map<String, (double?, double?, String, String)> _thresholds = {
  'hemoglobin': (11.0, 18.5, 'g/dL', 'Hemoglobin'),
  'hematocrit': (33.0, 52.0, '%', 'Hematocrit'),
  'rbc': (3.5, 6.5, 'x10(6)/uL', 'RBC'),
  'wbc': (3.0, 13.0, 'x10(3)/uL', 'WBC'),
  'platelets': (100.0, 500.0, 'x10(3)/uL', 'Platelets'),
  'mcv': (72.0, 108.0, 'fL', 'MCV'),
  'mchc': (30.0, 38.0, 'g/dL', 'MCHC'),
  'pulse': (50.0, 110.0, 'bpm', 'Pulse'),
  'temperature': (35.5, 38.0, 'celsius', 'Temperature'),
  'weight': (45.0, null, 'kg', 'Weight'),
  'systolic_bp': (85.0, 175.0, 'mmHg', 'Systolic BP'),
  'diastolic_bp': (55.0, 105.0, 'mmHg', 'Diastolic BP'),
  'ferritin': (8.0, 350.0, 'ng/mL', 'Ferritin'),
  'vdrl': (0.0, 0.80, 'binary', 'VDRL Syphilis'),
  'chronic_condition': (0.0, 0.80, 'binary', 'Chronic Condition'),
};

class _FlaggedValueTile extends StatelessWidget {
  const _FlaggedValueTile({required this.flagged});
  final _FlaggedValue flagged;

  @override
  Widget build(BuildContext context) {
    final isBelow = flagged.status == 'Below normal';
    final accent = isBelow ? AppColors.warning : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.06),
            accent.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              isBelow ? Icons.arrow_downward : Icons.arrow_upward,
              color: accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flagged.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${flagged.value} ${flagged.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: '  \u2022  ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      TextSpan(
                        text: 'Normal: ${flagged.range} ${flagged.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              flagged.status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
