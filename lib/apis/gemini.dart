import 'package:arxiv/models/chat_message.dart';
import 'package:arxiv/models/paper.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';

class Gemini {
  late final List<OpenAIChatCompletionChoiceMessageModel> _messages;
  String? _model;

  Gemini._internal(String systemPrompt, {String? model}) {
    _model = model;
    _messages = [
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.system,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            systemPrompt,
          )
        ],
      )
    ];
  }

  static Future<Gemini> newModel({Paper? paper, String? model}) async {
    // Load API settings from Hive
    Box apiBox = await Hive.openBox("apibox");
    String apiKey = await apiBox.get("apikey") ?? "";
    String baseUrl = await apiBox.get("baseUrl") ?? "";
    String savedModel = await apiBox.get("model") ?? "";
    await Hive.close();

    // Configure OpenAI with saved settings
    if (apiKey.isNotEmpty) {
      OpenAI.apiKey = apiKey;
    }
    if (baseUrl.isNotEmpty) {
      OpenAI.baseUrl = baseUrl;
    }

    final systemPrompt = paper != null
        ? await _getModelSystemMessage(paper)
        : await _getGeneralSystemMessage();
    return Gemini._internal(systemPrompt, model: model ?? (savedModel.isNotEmpty ? savedModel : null));
  }

  Future<ChatMessage> sendMessage(String message) async {
    try {
      _messages.add(OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            message,
          )
        ],
      ));
      
      var response = await OpenAI.instance.chat.create(
        model: _model ?? 'kimi-latest-8k',
        messages: _messages,
        temperature: 1,
        topP: 0.95,
        maxTokens: 8192,
      );
      
      var aiResponse = response.choices.first.message.content?.first.text ?? '';
      _messages.add(OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            aiResponse,
          )
        ],
      ));
      
      return ChatMessage(Role.assistant, aiResponse.trim());
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
