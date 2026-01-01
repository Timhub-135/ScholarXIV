import 'package:arxiv/models/chat_session.dart';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:ionicons/ionicons.dart';
import 'package:theme_provider/theme_provider.dart';
import 'package:intl/intl.dart';

class ChatHistoryPage extends StatefulWidget {
  final Function(ChatSession)? onSessionSelected;

  const ChatHistoryPage({super.key, this.onSessionSelected});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  List<ChatSession> chatSessions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load sessions immediately when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadChatSessions();
    });
  }

  Future<void> loadChatSessions() async {
    try {
      Box<ChatSession> sessionsBox = await Hive.openBox<ChatSession>('chat_sessions');
      // Load sessions from Hive
      setState(() {
        chatSessions = sessionsBox.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        isLoading = false;
      });
      
      await Hive.close();
    } catch (e) {
      // Handle error loading sessions
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      Box<ChatSession> sessionsBox = await Hive.openBox<ChatSession>('chat_sessions');
      await sessionsBox.delete(sessionId);
      
      setState(() {
        chatSessions.removeWhere((session) => session.id == sessionId);
      });
      
      await Hive.close();
    } catch (e) {
      // Handle error deleting session
    }
  }

  void showDeleteConfirmation(String sessionId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Chat Session'),
          content: const Text('Are you sure you want to delete this chat session?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                deleteSession(sessionId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadChatSessions,
            icon: const Icon(Ionicons.refresh_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadChatSessions,
        child: Container(
          color: ThemeProvider.themeOf(context).data.scaffoldBackgroundColor,
          child: isLoading && chatSessions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : chatSessions.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Ionicons.chatbubbles_outline,
                                    size: 64,
                                    color: ThemeProvider.themeOf(context)
                                        .data
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                        ?.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No chat history yet',
                                    style: TextStyle(
                                      color: ThemeProvider.themeOf(context)
                                          .data
                                          .textTheme
                                          .bodyLarge
                                          ?.color
                                          ?.withValues(alpha: 0.5),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start chatting to see your conversations here',
                                    style: TextStyle(
                                      color: ThemeProvider.themeOf(context)
                                          .data
                                          .textTheme
                                          .bodyLarge
                                          ?.color
                                          ?.withValues(alpha: 0.3),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: chatSessions.length,
                      itemBuilder: (context, index) {
                        final session = chatSessions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: session.hasPaper ? 2 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: session.hasPaper
                                ? BorderSide(
                                    color: ThemeProvider.themeOf(context)
                                        .data
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.2),
                                    width: 1,
                                  )
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () {
                              if (widget.onSessionSelected != null) {
                                widget.onSessionSelected!(session);
                              } else {
                                Navigator.pop(context, session);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                // Paper metadata header (only for paper-based chats)
                                if (session.hasPaper && session.paper != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: ThemeProvider.themeOf(context)
                                          .data
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: ThemeProvider.themeOf(context)
                                            .data
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: ThemeProvider.themeOf(context)
                                                .data
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            Ionicons.document_text_outline,
                                            size: 16,
                                            color: ThemeProvider.themeOf(context)
                                                .data
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Paper: ${session.paper!.title}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: ThemeProvider.themeOf(context)
                                                      .data
                                                      .colorScheme
                                                      .primary,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (session.paper!.authors.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    'Authors: ${session.paper!.authors is List ? (session.paper!.authors as List).join(', ') : session.paper!.authors}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: ThemeProvider.themeOf(context)
                                                          .data
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.color
                                                          ?.withValues(alpha: 0.8),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // Session content
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: session.hasPaper
                                            ? ThemeProvider.themeOf(context)
                                                .data
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1)
                                            : ThemeProvider.themeOf(context)
                                                .data
                                                .textTheme
                                                .bodyLarge
                                                ?.color
                                                ?.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        session.hasPaper
                                            ? Ionicons.document_text_outline
                                            : Ionicons.chatbubble_outline,
                                        size: 20,
                                        color: session.hasPaper
                                            ? ThemeProvider.themeOf(context)
                                                .data
                                                .colorScheme
                                                .primary
                                            : ThemeProvider.themeOf(context)
                                                .data
                                                .textTheme
                                                .bodyLarge
                                                ?.color
                                                ?.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: ThemeProvider.themeOf(context)
                                                  .data
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                Ionicons.chatbubble_outline,
                                                size: 14,
                                                color: ThemeProvider.themeOf(context)
                                                    .data
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color
                                                    ?.withValues(alpha: 0.6),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${session.messages.length} messages',
                                                style: TextStyle(
                                                  color: ThemeProvider.themeOf(context)
                                                    .data
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color
                                                    ?.withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Icon(
                                                Ionicons.time_outline,
                                                size: 14,
                                                color: ThemeProvider.themeOf(context)
                                                    .data
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color
                                                    ?.withValues(alpha: 0.5),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                formatDateTime(session.updatedAt),
                                                style: TextStyle(
                                                  color: ThemeProvider.themeOf(context)
                                                    .data
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color
                                                    ?.withValues(alpha: 0.5),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Ionicons.trash_outline,
                                        color: ThemeProvider.themeOf(context)
                                            .data
                                            .textTheme
                                            .bodyLarge
                                            ?.color
                                            ?.withValues(alpha: 0.5),
                                      ),
                                      onPressed: () => showDeleteConfirmation(session.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}