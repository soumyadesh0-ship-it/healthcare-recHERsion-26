import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';
import '../../data/api_client.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatMessage {
  const _ChatMessage(this.text, {this.fromAssistant = false, this.isError = false});

  final String text;
  final bool fromAssistant, isError;
}

class _ChatPageState extends State<ChatPage> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false, _confirming = false;

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmAiProcessing() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          var checked = false;
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Send this message to AI?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Only the message you typed will be sent to the AuraCare '
                    'backend and its configured AI provider. Your records and '
                    'chat history are not attached. Avoid sharing identifying '
                    'details.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checked,
                    title: const Text('I agree to AI processing of this message'),
                    onChanged: (value) =>
                        setDialogState(() => checked = value ?? false),
                  ),
                  const Text(
                    'AI responses can be wrong. This is general information, '
                    'not diagnosis or treatment. For urgent symptoms, seek '
                    'local emergency medical care.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: checked
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Send to AI'),
                ),
              ],
            ),
          );
        },
      ) ??
      false;

  Future<void> _send() async {
    if (_sending || _confirming || _composer.text.trim().isEmpty) return;
    final chat = SessionScope.of(context).chatService;
    if (chat == null) {
      tell(context, 'AI chat is available only after signing in.');
      return;
    }

    setState(() => _confirming = true);
    final confirmed = await _confirmAiProcessing();
    if (!mounted) return;
    setState(() => _confirming = false);
    if (!confirmed) return;

    final prompt = _composer.text.trim();
    setState(() => _sending = true);
    try {
      final response = await chat.send(
        prompt: prompt,
        aiProcessingConfirmed: true,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll([
          _ChatMessage(prompt),
          _ChatMessage(response, fromAssistant: true),
        ]);
        _composer.clear();
      });
      _scrollToLatest();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(
        _ChatMessage(error.message, fromAssistant: true, isError: true),
      ));
      _scrollToLatest();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatAvailable = SessionScope.of(context).chatService != null;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Palette.lavender,
              padding: const EdgeInsets.all(16),
              child: Text(
                chatAvailable
                    ? 'General health information only. The assistant is not '
                          'a doctor and cannot diagnose, prescribe, or handle '
                          'emergencies. Each message requires your consent.'
                    : 'AI chat is not available in demo mode. Sign in to use '
                          'the authenticated service; no messages are sent here.',
              ),
            ),
            if (!chatAvailable)
              const Expanded(
                child: Center(child: Text('No AI processing in demo mode.')),
              )
            else ...[
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'Ask a general health or wellbeing question. '
                            'Your records are never added to the message.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUser = !message.fromAssistant;
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 560),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: message.isError
                                    ? Palette.blush
                                    : isUser
                                    ? Palette.periwinkle
                                    : Palette.mist,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(message.text),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 10000,
                        enabled: !_sending && !_confirming,
                        decoration: const InputDecoration(
                          hintText: 'Type a general question',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: _sending || _confirming ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
