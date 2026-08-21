// =====================================================================
// chatbot_screen.dart — where the user talks to Clawd Bot, by typing
// OR by voice.
//
// UPDATED Aug 21: added voice input (speech_to_text) and spoken
// replies (flutter_tts). The chat/database logic from Aug 19-20 is
// unchanged - this just adds a microphone button and makes the bot
// speak its replies out loud.
// =====================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db_helper.dart';

const String kBackendBaseUrl = 'https://recede-nerd-sip.ngrok-free.dev';

// A friendly, specific message shown when voice recognition fails -
// e.g. no microphone permission, no speech detected, or the device
// doesn't support it. Better than a silent failure or a generic
// crash - the user always knows what happened and what to do next.
const String kVoiceFailureMessage =
    'Voice recognition has failed. Please try typing your message instead.';


class ChatMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? action;

  ChatMessage({required this.text, required this.isUser, this.action});
}


class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // ---- NEW TODAY: voice-related state ----
  final stt.SpeechToText _speech = stt.SpeechToText();   // does the listening
  final FlutterTts _flutterTts = FlutterTts();            // does the speaking
  bool _speechAvailable = false;   // true once mic/permissions are confirmed working
  bool _isListening = false;       // true while actively recording speech
  bool _voiceRepliesEnabled = true; // lets the user mute spoken replies

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  // Runs once when the screen first opens. Asks the speech_to_text
  // package to check microphone permission and device support. If
  // this fails (permission denied, unsupported device, etc.),
  // _speechAvailable stays false and the mic button will show the
  // voice failure message instead of trying to record.
  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (error) {
          setState(() {
            _isListening = false;
          });
          // Give a more specific, helpful message for the common
          // "didn't hear anything" case, rather than the generic
          // failure message for every kind of error.
          if (error.errorMsg == 'error_speech_timeout') {
            setState(() {
              _messages.add(ChatMessage(
                text: "I didn't hear anything — tap the mic and start "
                    "talking right away.",
                isUser: false,
              ));
            });
            _scrollToBottom();
          } else {
            _showVoiceFailure();
          }
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      setState(() {
        _speechAvailable = available;
      });
    } catch (e) {
      setState(() {
        _speechAvailable = false;
      });
    }
  }

  // Shows the SRS-specified voice failure message as a chat bubble,
  // so the user gets clear feedback rather than the mic button just
  // silently doing nothing.
  void _showVoiceFailure() {
    setState(() {
      _messages.add(ChatMessage(text: kVoiceFailureMessage, isUser: false));
    });
    _scrollToBottom();
  }

  // Called when the user taps the mic button.
  Future<void> _toggleListening() async {
    // Explicitly request microphone permission through Android's own
    // permission API first - on some devices (Samsung especially),
    // speech_to_text's internal permission handling doesn't fully
    // establish the audio session even when the permission shows as
    // already granted in Settings. This forces a proper handshake.
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Microphone permission is required for voice input. "
              "Please allow it in your phone's settings.",
          isUser: false,
        ));
      });
      return;
    }

    if (!_speechAvailable) {
      // Try initializing again, in case the user just granted
      // microphone permission after an earlier denial.
      await _initSpeech();
      if (!_speechAvailable) {
        _showVoiceFailure();
        return;
      }
    }

    if (_isListening) {
      // Already listening - tapping again stops it early.
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      setState(() {
        _isListening = true;
      });
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
          });
        },
        // Gives more patience before timing out - listenFor is the
        // total max listening time, pauseFor is how long it waits
        // during silence before deciding you're done talking.
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 5),
        // Explicitly specifying the locale is a common fix for the
        // speech_to_text plugin failing even when the device's own
        // keyboard voice-typing works fine.
        localeId: 'en_US',
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$kBackendBaseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text, 'user_id': 'default'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String replyText =
            data['reply'] ?? 'Sorry, I didn\'t understand that.';

        setState(() {
          _messages.add(ChatMessage(
            text: replyText,
            isUser: false,
            action: data['action'],
          ));
        });

        // ---- NEW TODAY: speak the bot's reply out loud ----
        if (_voiceRepliesEnabled) {
          await _flutterTts.speak(replyText);
        }

        await _executeAction(data['action']);
      } else {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Sorry, something went wrong on the server. Please try again.',
            isUser: false,
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Cannot connect to Clawd Bot right now. Please check your connection.',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _executeAction(Map<String, dynamic>? action) async {
    if (action == null) return;

    final String actionType = action['action'] ?? 'none';
    final Map<String, dynamic> data =
        (action['data'] as Map<String, dynamic>?) ?? {};

    switch (actionType) {
      case 'create_reminder':
        await DBHelper.instance.insertReminder({
          'task': data['task'] ?? '',
          'date': data['date'] ?? '',
          'time': data['time'] ?? '',
          'priority': data['priority'] ?? 'green',
          'completed': 0,
        });
        await DBHelper.instance.logContext('reminder_created');

        setState(() {
          _messages.add(ChatMessage(
            text: '✅ Saved to your reminders.',
            isUser: false,
          ));
        });
        break;

      case 'find_object':
        final String query = (data['query'] ?? '').toString().toLowerCase();
        final locations = await DBHelper.instance.getObjectLocations();

        Map<String, dynamic> match = <String, dynamic>{};
        for (final loc in locations) {
          final name = (loc['object_name'] as String).toLowerCase();
          if (name.contains(query)) {
            match = loc;
            break;
          }
        }

        final String replyText = match.isNotEmpty
            ? "I found it — you saved '${match['object_name']}' at ${match['location_name'] ?? 'an unknown spot'}."
            : "I couldn't find anything saved for '$query'. You can add it on the Memory screen.";

        setState(() {
          _messages.add(ChatMessage(text: replyText, isUser: false));
        });
        break;

      case 'find_note':
        final String query = (data['query'] ?? '').toString().toLowerCase();
        final notes = await DBHelper.instance.getNotes();

        final matches = notes.where((n) {
          final title = (n['title'] as String? ?? '').toLowerCase();
          final content = (n['content'] as String? ?? '').toLowerCase();
          return title.contains(query) || content.contains(query);
        }).toList();

        final String replyText = matches.isNotEmpty
            ? "Found ${matches.length} note(s): ${matches.map((n) => n['title']).join(', ')}"
            : "I couldn't find any notes about '$query'.";

        setState(() {
          _messages.add(ChatMessage(text: replyText, isUser: false));
        });
        break;

      case 'list_tasks':
        final reminders = await DBHelper.instance.getReminders();

        String replyText;
        if (reminders.isEmpty) {
          replyText = "You don't have any reminders set yet.";
        } else {
          final list = reminders
              .take(5)
              .map((r) => "• ${r['task']} (${r['date']} ${r['time']})")
              .join('\n');
          replyText = "Here's what you have:\n$list";
        }

        setState(() {
          _messages.add(ChatMessage(text: replyText, isUser: false));
        });
        break;

      default:
        break;
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Clawd Bot'),
        actions: [
          // A simple mute/unmute toggle for spoken replies, so the
          // user isn't forced to hear every response out loud.
          IconButton(
            icon: Icon(
              _voiceRepliesEnabled ? Icons.volume_up : Icons.volume_off,
            ),
            tooltip: _voiceRepliesEnabled
                ? 'Voice replies on'
                : 'Voice replies off',
            onPressed: () {
              setState(() {
                _voiceRepliesEnabled = !_voiceRepliesEnabled;
              });
              if (!_voiceRepliesEnabled) {
                _flutterTts.stop();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Say hi to Clawd Bot, or ask it to set a reminder! '
                        'Tap the mic to talk instead of typing.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _ChatBubble(message: _messages[index]);
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          // A small visual cue that the mic is actively listening -
          // without this, the user has no idea if it's working.
          if (_isListening)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '🎙️ Listening...',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type or tap the mic to talk...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 4),
                // ---- NEW TODAY: the mic button ----
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : null,
                  ),
                  onPressed: _isLoading ? null : _toggleListening,
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[400] : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}