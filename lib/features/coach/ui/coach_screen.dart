import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/features/coach/models/chat_message.dart';
import 'package:fantastic_guacamole/features/coach/state/chat_provider.dart';
import 'package:fantastic_guacamole/features/coach/ui/coach_message.dart';
import 'package:fantastic_guacamole/features/coach/ui/user_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);

    ref.listen(chatProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B111C),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'COACH',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            color: AppColors.neonCyan,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.neonCyan,
                      strokeWidth: 2,
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      return msg.author == ChatAuthor.coach
                          ? CoachMessage(text: msg.text)
                          : UserMessage(text: msg.text);
                    },
                  ),
          ),
          _InputBar(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1420),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask your coach...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A2440),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              color: AppColors.neonCyan,
            ),
          ],
        ),
      ),
    );
  }
}
