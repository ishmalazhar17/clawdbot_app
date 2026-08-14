// =====================================================================
// chatbot_screen.dart — where the user talks to Clawd Bot, by typing
// or (later) by voice.
//
// TODAY'S STATUS: placeholder UI. Real chat bubbles + calling Person
// A's /chat endpoint get built on Aug 19.
// =====================================================================

import 'package:flutter/material.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with Clawd Bot')),
      body: const Center(
        child: Text(
          'Chat interface coming Aug 19.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}