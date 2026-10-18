import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Measure heights of input bar and voice recorder bar', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              // 1. Text field from chat_screen
              ConstrainedBox(
                key: const ValueKey('textFieldBox'),
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Nhắn tin...',
                    hintStyle: const TextStyle(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  maxLines: null,
                ),
              ),

              // 2. Middle pill from voice_recorder_bar
              Container(
                key: const ValueKey('voiceBarMiddlePill'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.pause_fill,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '0:05',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(
                      height: 18,
                      child: SizedBox(width: 50),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final textRenderBox = tester.renderObject<RenderBox>(find.byKey(const ValueKey('textFieldBox')));
    final voiceRenderBox = tester.renderObject<RenderBox>(find.byKey(const ValueKey('voiceBarMiddlePill')));

    print('TextField height: ${textRenderBox.size.height}');
    print('VoiceBar middle pill height: ${voiceRenderBox.size.height}');
  });
}
