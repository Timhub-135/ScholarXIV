// ignore_for_file: file_names

import 'package:arxiv/apis/gemini.dart';
import 'package:arxiv/components/api_settings.dart';
import 'package:arxiv/components/each_chat_message.dart';
import 'package:arxiv/components/prompt_suggestions.dart';
import 'package:arxiv/models/chat_message.dart';
import 'package:arxiv/models/paper.dart';
import 'package:arxiv/models/chat_session.dart';
import 'package:arxiv/pages/chat_history_page.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:ionicons/ionicons.dart';
import 'package:theme_provider/theme_provider.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key, required this.paperData});

  final Paper? paperData;

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  TextEditingController userMessageController = TextEditingController();
  ScrollController scrollController = ScrollController();
  var apiKey = "";
  List<ChatMessage> chatList = [];
  var apiKeySettingsOn = false;
   var toolsOn = true;
   String? currentSessionId;

  //  final _systemLoadingTrigger = "SYMLOADINGANIMATION";

  late Gemini model;

  var paperPromptSuggestions = [
    "Who wrote this paper?",
    "What is the title of this paper?",
    "What is the summary of this paper?",
    "What is the significance of this paper?",
    "Tell me a joke based on this paper's title?",
    "Can you explain like I am five years old?",
    "What do you know about the authors?",
    "Suggest and list related papers?",
    "How can this apply to my life?",
  ];

  var generalPromptSuggestions = [
    "What is arXiv?",
    "Tell me about ScholArxiv?",
    "Most profound research papers published?",
    "How can I get started writing research papers?",
    "Precautions to take while reading research papers?",
    "Where can I view the source code of ScholArxiv?",
    "List the main sections of research papers?",
    "Purpose of research papers?",
  ];

  void scrollToTheBottom() {
    setState(() {});
    try {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      //
    }
  }

  void chatWithAI() async {
    var message = userMessageController.text.trim();
    userMessageController.clear();

    if (message != "") {
      // Add user message and save immediately
      chatList.add(ChatMessage(Role.user, message));
      scrollToTheBottom();
      await saveCurrentSession();

      // Add AI message placeholder and save
      var aiMessage = ChatMessage(Role.assistant, "");
      chatList.add(aiMessage);
      scrollToTheBottom();
      await saveCurrentSession();

      // Stream AI response and save after each chunk
      await model.sendMessageStream(message, (chunk) async {
        setState(() {
          aiMessage.content += chunk;
        });
        scrollToTheBottom();
        // Auto-save after each chunk to ensure progress is saved
        await saveCurrentSession();
      });

      scrollToTheBottom();
      
      // Final save after AI response completes
      await saveCurrentSession();
    }
  }

  Future<void> saveCurrentSession() async {
    try {
      Box<ChatSession> sessionsBox = await Hive.openBox<ChatSession>('chat_sessions');
      
      // Always prioritize paper title for session title
      String title;
      if (widget.paperData != null && widget.paperData!.title.isNotEmpty) {
        // Use paper title, truncate if too long
        title = widget.paperData!.title.length > 80 
            ? "${widget.paperData!.title.substring(0, 80)}..." 
            : widget.paperData!.title;
      } else if (chatList.isNotEmpty) {
        // Fall back to first user message for non-paper chats
        var firstUserMessage = chatList.firstWhere(
          (msg) => msg.role == Role.user,
          orElse: () => ChatMessage(Role.user, "General Chat"),
        );
        title = firstUserMessage.content.length > 50 
            ? "${firstUserMessage.content.substring(0, 50)}..." 
            : firstUserMessage.content;
      } else {
        // Empty chat session
        title = widget.paperData != null ? "Paper Discussion" : "New Chat";
      }
      
      ChatSession session;
      if (currentSessionId != null) {
        // Update existing session
        var existingSession = sessionsBox.get(currentSessionId);
        if (existingSession != null) {
          session = existingSession.copyWith(
            title: title,
            messages: List.from(chatList),
          );
          await sessionsBox.put(currentSessionId, session);
        }
      } else {
        // Create new session
        session = ChatSession.create(
          title: title,
          paper: widget.paperData,
          messages: List.from(chatList),
        );
        currentSessionId = session.id;
        await sessionsBox.put(session.id, session);
      }
      
      await Hive.close();
    } catch (e) {
      // Handle error saving chat session
      print('Error saving chat session: $e');
    }
  }

  Future<void> loadSession(ChatSession session) async {
    setState(() {
      chatList.clear();
      chatList.addAll(session.messages);
      currentSessionId = session.id;
    });
    
    // Scroll to bottom after loading
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollToTheBottom();
    });
  }

  Future<void> loadSessionFromHistory(ChatSession session) async {
    setState(() {
      chatList.clear();
      chatList.addAll(session.messages);
      currentSessionId = session.id;
    });
    
    // Scroll to bottom after loading
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollToTheBottom();
    });
  }

  void clearChat() async {
    chatList.clear();
    currentSessionId = null;
    setState(() {});
  }

  void configModel() async {
    Box apiBox = await Hive.openBox("apibox");
    apiKey = await apiBox.get("apikey") ?? "";
    await Hive.close();

    if (apiKey.isNotEmpty) {
      model = await Gemini.newModel(paper: widget.paperData);
      apiKeySettingsOn = false;
    } else {
      apiKeySettingsOn = true;
    }
    setState(() {});
  }

  void toggleAPIKeySettings() {
    apiKeySettingsOn = !apiKeySettingsOn;
    setState(() {});
  }

  void toggleTools() async {
    toolsOn = !toolsOn;
    Box toolsBox = await Hive.openBox("toolsBox");
    await toolsBox.put("toolsBox", toolsOn);
    await Hive.close();
    setState(() {});
  }

  void getToggleTools() async {
    Box toolsBox = await Hive.openBox("toolsBox");
    toolsOn = await toolsBox.get("toolsBox") ?? true;
    await Hive.close();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    getToggleTools();
    // Initialize model in the next frame to avoid setState called during build errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      configModel();
    });
    // Initialize session for paper-based chats
    if (widget.paperData != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        saveInitialSession();
      });
    }
  }

  Future<void> saveInitialSession() async {
    if (chatList.isEmpty && widget.paperData != null) {
      try {
        Box<ChatSession> sessionsBox = await Hive.openBox<ChatSession>('chat_sessions');
        
        String title = widget.paperData!.title.length > 80 
            ? "${widget.paperData!.title.substring(0, 80)}..." 
            : widget.paperData!.title;
        
        ChatSession session = ChatSession.create(
          title: title,
          paper: widget.paperData,
          messages: [],
        );
        currentSessionId = session.id;
        await sessionsBox.put(session.id, session);
        await Hive.close();
      } catch (e) {
        print('Error saving initial session: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ScholArxiv AI"),
        actions: [
        // CHAT HISTORY
        IconButton(
          onPressed: () async {
            final selectedSession = await Navigator.push<ChatSession>(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatHistoryPage(),
              ),
            );
            
            if (selectedSession != null) {
              await loadSessionFromHistory(selectedSession);
            }
          },
          icon: const Icon(
            Icons.history,
          ),
        ),
        // TOGGLE TOOLS
        IconButton(
          onPressed: () {
            toggleTools();
          },
          icon: const Icon(
            Icons.menu_open_rounded,
          ),
        ),
        // API KEY SETTINGS
        IconButton(
          onPressed: () {
            toggleAPIKeySettings();
          },
          icon: const Icon(
            Ionicons.key_outline,
          ),
        ),

        // CLEAR CHAT
        IconButton(
          onPressed: () {
            clearChat();
          },
          icon: const Icon(
            Icons.delete_forever_outlined,
          ),
        ),
        const SizedBox(width: 5.0),
      ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10.0),

          Expanded(
            child: chatList.isEmpty || apiKeySettingsOn == true
                ? ListView(
                    padding: const EdgeInsets.only(top: 30.0),
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Icon(
                              Icons.auto_awesome_outlined,
                              size: 30.0,
                              color: ThemeProvider.themeOf(context)
                                  .data
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 50.0,
                            ),
                            child: const Text(
                              "You can have conversations about the current paper here.",
                              textAlign: TextAlign.center,
                            ),
                          ),
                          apiKeySettingsOn == true
                              ? APISettings(
                                  configAPIKey: configModel,
                                )
                              : PromptSuggestions(
                                  chatWithAI: chatWithAI,
                                  userMessageController: userMessageController,
                                  promptSuggestions: widget.paperData == null
                                      ? generalPromptSuggestions
                                      : paperPromptSuggestions,
                                ),
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: chatList.length,
                    itemBuilder: (context, index) {
                      final item = chatList[index];
                      return EachChatMessage(
                        response: item,
                        toolsOn: toolsOn,
                      );
                    },
                  ),
          ),
          // Chat Box and Send Button
          Padding(
            padding: const EdgeInsets.only(left: 10.0, bottom: 8.0, top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 18.0, right: 18.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30.0),
                      color: ThemeProvider.themeOf(context)
                              .data
                              .textTheme
                              .bodyLarge
                              ?.color
                              ?.withAlpha(12) ??
                          Colors.grey[100],
                    ),
                    child: TextField(
                      controller: userMessageController,
                      enabled: !(apiKeySettingsOn == true),
                      cursorColor:
                          ThemeProvider.themeOf(context).id == "dark_theme"
                              ? Colors.white
                              : ThemeProvider.themeOf(context)
                                  .data
                                  .textTheme
                                  .bodyLarge
                                  ?.color,
                      style: TextStyle(
                        color: ThemeProvider.themeOf(context).id == "dark_theme"
                            ? Colors.white
                            : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.paperData.toString() == ""
                            ? "ask about anything..."
                            : 'ask about the paper...',
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    onPressed: () {
                      apiKey == "" ? () {} : chatWithAI();
                    },
                    icon: Icon(
                      Ionicons.paper_plane_outline,
                      color: ThemeProvider.themeOf(context)
                          .data
                          .textTheme
                          .bodyLarge
                          ?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
