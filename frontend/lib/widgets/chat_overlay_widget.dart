import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../controllers/chat_controller.dart';

class ChatOverlayWidget extends StatefulWidget {
  final ChatController chatController;

  const ChatOverlayWidget({Key? key, required this.chatController})
      : super(key: key);

  @override
  _ChatOverlayWidgetState createState() => _ChatOverlayWidgetState();
}

class _ChatOverlayWidgetState extends State<ChatOverlayWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.isNotEmpty) {
      widget.chatController.sendMessage(_textController.text);
      _textController.clear();
      _focusNode.requestFocus(); // Keep focus on input
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a Consumer to rebuild when ChatController notifies listeners
    return Consumer<ChatController>(
      builder: (context, controller, child) {
        // Position the chat window in the bottom right
        return Positioned(
          bottom: 20,
          right: 20,
          child: Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(16.0),
            clipBehavior:
                Clip.antiAlias, // Ensures content respects border radius
            child: Container(
              width: 350, // Adjust width as needed
              height: 500, // Adjust height as needed
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // Use theme card color
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  _buildHeader(context, controller),
                  // Message List
                  Expanded(
                    child: ListView.builder(
                      controller: controller
                          .scrollController, // Use controller's scrollController
                      padding: const EdgeInsets.all(10.0),
                      itemCount: controller.messages.length,
                      itemBuilder: (context, index) {
                        final message = controller.messages[index];
                        return _buildMessageItem(context, message);
                      },
                    ),
                  ),
                  // Loading Indicator
                  if (controller.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: LinearProgressIndicator(),
                    ),
                  // Input Area
                  _buildInputArea(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ChatController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'StoreSense AI',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () => controller.hideChatOverlay(),
            tooltip: 'Cerrar chat',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, ChatMessage message) {
    final bool isUser = message.isUser;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondaryContainer;
    final textColor = isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSecondaryContainer;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
                bottomLeft: Radius.circular(isUser ? 16.0 : 0),
                bottomRight: Radius.circular(isUser ? 0 : 16.0),
              ),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width *
                  0.6, // Max width 60% of chat width
            ),
            child: Text(
              message.text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: textColor),
            ),
          ),
          const SizedBox(height: 2.0),
          // Optionally display timestamp
          // Text(
          //   DateFormat('HH:mm').format(message.timestamp), // Format time
          //   style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
          // ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor, // Match background
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).dividerColor, width: 0.5)),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          )),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                border: InputBorder.none,
                filled: false, // Don't fill inside the input area container
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _sendMessage,
            tooltip: 'Enviar mensaje',
          ),
        ],
      ),
    );
  }
}
