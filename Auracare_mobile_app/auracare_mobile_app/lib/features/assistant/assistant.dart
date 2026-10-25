import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/session.dart';
import '../../data/api_client.dart';
import '../../data/chat_service.dart';
import '../chat/chat.dart' show confirmAiProcessing;

/// Embedded in the existing assistant route's Scaffold.
class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key, this.service});
  final ChatService? service;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  AuthenticatedChatService? get accountService => context
      .dependOnInheritedWidgetOfExactType<SessionScope>()
      ?.notifier
      ?.chatService;
  bool get configured => widget.service?.configured ?? accountService != null;
  final messages = <({bool user, String text})>[];
  bool sending = false;
  bool confirming = false;
  String? error;

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void showLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> send() async {
    final prompt = input.text.trim();
    if (sending || confirming || prompt.isEmpty || !configured) return;
    final chat = accountService;
    if (widget.service == null) {
      setState(() => confirming = true);
      final confirmed = await confirmAiProcessing(context);
      if (!mounted) return;
      setState(() => confirming = false);
      if (!confirmed) return;
    }
    setState(() {
      messages.add((user: true, text: prompt));
      sending = true;
      error = null;
      input.clear();
    });
    showLatest();
    try {
      final reply = widget.service != null
          ? await widget.service!.send(prompt)
          : await chat!.send(prompt: prompt, aiProcessingConfirmed: true);
      if (!mounted) return;
      setState(() => messages.add((user: false, text: reply)));
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        input.text = prompt;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        input.text = prompt;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'The assistant is unavailable. Your message is ready to retry.';
        input.text = prompt;
      });
    } finally {
      if (mounted) {
        setState(() => sending = false);
        showLatest();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Assistant',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask AuraCare a question. AI replies are general information, not medical advice. Only your message is sent.',
            ),
          ],
        ),
      ),
      Expanded(
        child: messages.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'What would you like to ask?',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Align(
                    alignment: message.user
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      constraints: const BoxConstraints(maxWidth: 560),
                      decoration: BoxDecoration(
                        color: message.user ? Palette.lavender : Palette.input,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.user ? 'You' : 'AuraCare',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(message.text),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      if (sending)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('AuraCare is replying...'),
            ],
          ),
        ),
      if (!configured || error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            error ??
                (widget.service != null
                    ? 'Chat is not configured. Set API_BASE_URL and rebuild the app.'
                    : 'Sign in to use AI chat. No messages are sent in demo mode.'),
            semanticsLabel: error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('chat-input'),
                controller: input,
                enabled: configured && !sending && !confirming,
                minLines: 1,
                maxLines: 4,
                maxLength: 10000,
                decoration: const InputDecoration(
                  hintText: 'Type your message',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('chat-send'),
              tooltip: 'Send message',
              onPressed: sending || confirming || !configured ? null : send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    ],
  );
}
