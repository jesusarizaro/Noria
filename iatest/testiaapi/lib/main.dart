import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';

void main() {
  runApp(VoiceChatGPTApp());
}

class VoiceChatGPTApp extends StatelessWidget {
  // Replace with your actual API key
  final String apiKey = 'sk-YourAPIKeyHere';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice ChatGPT Assistant',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: VoiceChatGPTPage(apiKey: apiKey),
    );
  }
}

class VoiceChatGPTPage extends StatefulWidget {
  final String apiKey;
  const VoiceChatGPTPage({Key? key, required this.apiKey}) : super(key: key);

  @override
  _VoiceChatGPTPageState createState() => _VoiceChatGPTPageState();
}

class _VoiceChatGPTPageState extends State<VoiceChatGPTPage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _displayText = "Tap the mic to start speaking";
  late FlutterTts _flutterTts;
  late ChatGPT openAI;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    // Initialize the ChatGPT client with your API key.
    openAI = ChatGPT(apiKey: widget.apiKey);
  }

  // Toggle listening: start if not listening, or stop and send query if currently listening.
  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _displayText = "Listening...";
        });
        _speech.listen(
          onResult: (result) {
            setState(() {
              _displayText = result.recognizedWords;
            });
          },
        );
      } else {
        setState(() {
          _displayText = "Speech recognition not available";
        });
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
      await _sendQueryToGPT(_displayText);
    }
  }

  // Send the recognized text to GPT via chat_gpt_sdk.
  Future<void> _sendQueryToGPT(String query) async {
    try {
      // Construct a chat completion request.
      // Use the 'messages' parameter with a list containing a user message.
      final request = ChatCompleteText(
        messages: [
          ChatMessage(
            role: ChatMessageRole.user,
            content: query,
          ),
        ],
        model: ChatModel.gptTurbo, // Using GPT-3.5 Turbo as an example.
      );
      final response = await openAI.onChatCompletion(request: request);
      if (response != null && response.choices.isNotEmpty) {
        // Retrieve the answer from the first choice's message content.
        final answer = response.choices.first.message?.content ?? "No content";
        setState(() {
          _displayText = answer;
        });
        await _flutterTts.speak(answer);
      } else {
        setState(() {
          _displayText = "No response received.";
        });
      }
    } catch (e) {
      setState(() {
        _displayText = "Error: $e";
      });
      print("Exception in _sendQueryToGPT: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Voice ChatGPT Assistant"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _displayText,
            style: TextStyle(fontSize: 18.0),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }
}
