// =====================================================================
// suggestions_screen.dart — shows proactive suggestions based on the
// user's own reminder history, with color-coded priority cards.
//
// HOW THIS SCREEN WORKS, IN PLAIN ENGLISH:
//   1. When the screen opens (or the user pulls down to refresh), we
//      read ALL of the user's past reminders from the local database.
//   2. We send that history to the backend's /suggestions endpoint.
//   3. The backend looks for repeating patterns (e.g. "you often set
//      a reminder for X around 6pm") and sends back a list of
//      suggestion cards.
//   4. We display them, color-coded: green = mild pattern,
//      yellow = solid pattern, red = very strong/frequent pattern.
//
// This is a genuinely different design from most screens so far -
// the DATA originates on the phone (reminder history), gets SENT to
// the backend for analysis, and the RESULT comes back to display.
// Neither side could do this alone: the phone has the data but not
// the pattern-detection logic, and the backend has the logic but not
// the data.
// =====================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../db_helper.dart';

const String kBackendBaseUrl = 'https://recede-nerd-sip.ngrok-free.dev';


// A simple data class for one suggestion card.
class SuggestionItem {
  final String text;
  final String priority;   // "green" | "yellow" | "red"

  SuggestionItem({required this.text, required this.priority});

  // A "factory constructor" - a special kind of constructor that
  // builds a SuggestionItem FROM a JSON map (like what jsonDecode
  // gives us), rather than requiring you to pass text/priority
  // directly. This keeps the JSON-parsing logic in one clean place.
  factory SuggestionItem.fromJson(Map<String, dynamic> json) {
    return SuggestionItem(
      text: json['text'] ?? '',
      priority: json['priority'] ?? 'green',
    );
  }
}


class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  List<SuggestionItem> _suggestions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load suggestions automatically the moment this screen opens,
    // so the user doesn't have to manually trigger a refresh first.
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ---- STEP 1: read the user's reminder history from the
      // LOCAL database (this is data the backend has no access to). ----
      final reminders = await DBHelper.instance.getReminders();

      // Convert each reminder's Map into the exact shape the backend
      // expects: {"task": ..., "date": ..., "time": ...} - dropping
      // fields like "id", "priority", "completed" that the backend
      // doesn't need for pattern analysis.
      final historyForBackend = reminders
          .map((r) => {
                'task': r['task'],
                'date': r['date'],
                'time': r['time'],
              })
          .toList();

      // ---- STEP 2: send that history to the backend for analysis ----
      final response = await http.post(
        Uri.parse('$kBackendBaseUrl/suggestions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'default',
          'reminder_history': historyForBackend,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> rawSuggestions = data['suggestions'] ?? [];

        setState(() {
          _suggestions = rawSuggestions
              .map((s) => SuggestionItem.fromJson(s))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Something went wrong loading suggestions. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Cannot connect to Clawd Bot right now. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  // Maps a priority string to an actual Flutter Color, used for the
  // colored left-edge stripe on each suggestion card.
  Color _colorForPriority(String priority) {
    switch (priority) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.amber;
      case 'green':
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions')),
      // RefreshIndicator adds the standard "pull down to refresh"
      // gesture - wrapping it around the whole body means the user
      // can swipe down anywhere on this screen to reload.
      body: RefreshIndicator(
        onRefresh: _loadSuggestions,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      // ListView (not just Center/Text) is used here even for the
      // error state, so pull-to-refresh still works even when
      // there's nothing else to show - RefreshIndicator needs a
      // scrollable child to detect the pull gesture.
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ),
        ],
      );
    }

    if (_suggestions.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "No suggestions yet. As you use Clawd Bot more, "
                "it'll start noticing patterns in your reminders "
                "and suggest things here.",
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // A thin colored stripe on the left edge of the card,
                // giving an at-a-glance priority indicator - matches
                // the SRS's color-coded suggestion requirement.
                Container(
                  width: 6,
                  color: _colorForPriority(suggestion.priority),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(suggestion.text),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}