import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart'; // Correct path assuming config.dart is in lib/
import 'auth_controller.dart'; // To get the auth token
import '../widgets/chat_overlay_widget.dart'; // Import the overlay widget

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage(
      {required this.text, required this.isUser, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        // History sent to backend doesn't need timestamp
      };
}

class ChatController extends ChangeNotifier {
  final AuthController _authController; // Inject AuthController
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isOverlayVisible => _isOverlayVisible;

  // Constructor requires AuthController
  ChatController(this._authController) {
    // Add initial greeting from AI when controller is created
    _messages.add(ChatMessage(
      text: "¡Hola! Soy StoreSense AI. ¿En qué puedo ayudarte hoy?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isLoading = true;
    notifyListeners(); // Update UI to show user message and loading state

    try {
      final token = _authController.token;
      if (token == null) {
        throw Exception("User not authenticated");
      }

      // Prepare history: only send last N messages to avoid large payloads
      const int historyLimit = 10;
      final historyToSend = _messages.length <=
              historyLimit + 1 // +1 because we exclude the current user message
          ? _messages.sublist(
              0, _messages.length - 1) // Exclude current user message
          : _messages.sublist(
              _messages.length - historyLimit - 1, _messages.length - 1);

      final response = await http.post(
        Uri.parse(AppConfig.getApiUrl('chat/ai')),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': userMessage.text,
          'history': historyToSend.map((m) => m.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final responseData =
            jsonDecode(utf8.decode(response.bodyBytes)); // Handle UTF-8
        final aiReply = responseData['reply'];
        _messages.add(ChatMessage(
          text: aiReply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      } else {
        // Try to decode error message from backend
        String errorMessage = "Error ${response.statusCode}";
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (_) {
          // Use default error message if decoding fails
        }
        _messages.add(ChatMessage(
          text: "Error al contactar al asistente: $errorMessage",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        print("Error sending message: ${response.statusCode}");
        print("Response body: ${utf8.decode(response.bodyBytes)}");
      }
    } catch (e) {
      print("Exception sending message: $e");
      _messages.add(ChatMessage(
        text: "No se pudo conectar con el asistente. Inténtalo de nuevo.",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } finally {
      _isLoading = false;
      notifyListeners(); // Update UI with AI response/error and stop loading
      _scrollToBottom(); // Scroll after update
    }
  }

  // --- Overlay Management ---

  void toggleChatOverlay(BuildContext context) {
    if (_isOverlayVisible) {
      hideChatOverlay();
    } else {
      showChatOverlay(context);
    }
  }

  void showChatOverlay(BuildContext context) {
    if (_isOverlayVisible) return; // Don't show if already visible

    _overlayEntry = OverlayEntry(
      builder: (context) => ChatOverlayWidget(chatController: this),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isOverlayVisible = true;
    notifyListeners();
    _scrollToBottom(); // Scroll when opening
  }

  void hideChatOverlay() {
    if (!_isOverlayVisible || _overlayEntry == null) return;

    try {
      _overlayEntry?.remove();
    } catch (e) {
      print("Error removing overlay entry: $e");
      // It might already be removed or in an invalid state
    }
    _overlayEntry = null;
    _isOverlayVisible = false;
    notifyListeners();
  }

  // --- Scroll Controller ---
  // Used by the ChatOverlayWidget to scroll to the bottom
  final ScrollController scrollController = ScrollController();

  void _scrollToBottom() {
    // Needs a slight delay for the list view to update its dimensions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    hideChatOverlay(); // Ensure overlay is removed when controller is disposed
    super.dispose();
  }
}
