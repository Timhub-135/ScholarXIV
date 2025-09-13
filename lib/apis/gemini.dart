import 'package:arxiv/models/chat_message.dart';
import 'package:arxiv/models/paper.dart';
import 'package:openai_flutter/openai_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class Gemini {
  late final OpenAIClient _client;
  late final List<OpenAIChatCompletionRequestMessage> _messages;

  Gemini._internal(String apiKey, String systemPrompt, {String? baseUrl, String? model}) {
    _client = OpenAIClient(
      apiKey: apiKey,
      organizationId: '',
      baseUrl: baseUrl,
    );
    
    _messages = [
      OpenAIChatCompletionRequestMessage(
        role: OpenAIChatMessageRole.system,
        content: systemPrompt,
      )
    ];
  }

  static Future<Gemini> newModel(String apiKey, {Paper? paper, String? baseUrl, String? model}) async {
    final systemPrompt = paper != null
        ? await _getModelSystemMessage(paper)
        : await _getGeneralSystemMessage();
    return Gemini._internal(apiKey, systemPrompt, baseUrl: baseUrl, model: model);
  }

  Future<ChatMessage> sendMessage(String message) async {
    try {
      _messages.add(OpenAIChatCompletionRequestMessage(
        role: OpenAIChatMessageRole.user,
        content: message,
      ));
      
      var response = await _client.createChatCompletion(
        model: model ?? 'kimi-latest-8k',
        messages: _messages,
        temperature: 1,
        topP: 0.95,
        maxTokens: 8192,
      );
      
      var aiResponse = response.choices.first.message.content;
      _messages.add(OpenAIChatCompletionRequestMessage(
        role: OpenAIChatMessageRole.assistant,
        content: aiResponse,
      ));
      
      return ChatMessage(Role.ai, aiResponse?.trim() ?? "");
    } catch (e) {
      return ChatMessage(Role.ai, e.toString());
    }
  }

  static Future<String> _getModelSystemMessage(Paper paper) async {
    var substitutes = {
      'paperId': paper.id,
      'paperTitle': paper.title,
      'paperAuthors': paper.authors,
      'paperPublishedDate': paper.publishedAt,
      'paperSummary': paper.summary,
    };

    return await _fromTemplateFile(
        'assets/system_message_templates/model.txt', substitutes);
  }

  static Future<String> _getGeneralSystemMessage() async {
    return await _fromTemplateFile(
        'assets/system_message_templates/general.txt', {});
  }

  /// Interpolates values to a text read from a file. The format for a placeholder is {{some_name}}.
  static Future<String> _fromTemplateFile(
      String fileName, Map<String, dynamic> substitutes) async {
    var template = await rootBundle.loadString(fileName);
    return template.splitMapJoin(RegExp('{{.*?}}'),
        onMatch: (m) => substitutes[_getPlaceholderName(m.group(0))] ?? '');
  }

  static String _getPlaceholderName(String? placeholderTemplate) {
    if (placeholderTemplate == null) return '';

    return placeholderTemplate.substring(2, placeholderTemplate.length - 2);
  }
}
