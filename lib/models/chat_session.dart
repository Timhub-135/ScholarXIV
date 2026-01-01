import 'package:hive/hive.dart';
import 'package:arxiv/models/chat_message.dart';
import 'package:arxiv/models/paper.dart';

part 'chat_session.g.dart';

@HiveType(typeId: 2)
class ChatSession {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final DateTime createdAt;
  
  @HiveField(3)
  final DateTime updatedAt;
  
  @HiveField(4)
  final Paper? paper;
  
  @HiveField(5)
  final List<ChatMessage> messages;
  
  @HiveField(6)
  final bool hasPaper;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.paper,
    required this.messages,
    required this.hasPaper,
  });

  factory ChatSession.create({
    required String title,
    Paper? paper,
    required List<ChatMessage> messages,
  }) {
    final now = DateTime.now();
    return ChatSession(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: now,
      updatedAt: now,
      paper: paper,
      messages: messages,
      hasPaper: paper != null,
    );
  }

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    Paper? paper,
    List<ChatMessage>? messages,
    bool? hasPaper,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      paper: paper ?? this.paper,
      messages: messages ?? this.messages,
      hasPaper: hasPaper ?? this.hasPaper,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'paper': paper?.toJson(),
        'messages': messages.map((msg) => {
          'role': msg.role.toString().split('.').last,
          'content': msg.content,
        }).toList(),
        'hasPaper': hasPaper,
      };

  @override
  String toString() {
    return 'ChatSession(id: $id, title: $title, createdAt: $createdAt, updatedAt: $updatedAt, hasPaper: $hasPaper, messagesCount: ${messages.length})';
  }
}