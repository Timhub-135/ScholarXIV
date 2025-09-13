enum Role { ai, user, system, assistant }

class ChatMessage {
  Role role;
  String content;

  ChatMessage(this.role, this.content);
}
