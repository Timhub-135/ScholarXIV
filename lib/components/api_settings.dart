// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:theme_provider/theme_provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class APISettings extends StatefulWidget {
  const APISettings({super.key, required this.configAPIKey});

  final Function configAPIKey;

  @override
  State<APISettings> createState() => _APISettingsState();
}

class _APISettingsState extends State<APISettings> {
  TextEditingController apiKeyController = TextEditingController();
  TextEditingController baseUrlController = TextEditingController();
  TextEditingController modelController = TextEditingController();
  var apiKey = "";
  var baseUrl = "";
  var model = "";
  var enableChineseTranslation = true;



  void saveAPIKey() async {
    var newAPIKey = apiKeyController.text.trim();
    var newBaseUrl = baseUrlController.text.trim();
    var newModel = modelController.text.trim();
    
    if (newAPIKey != "") {
      Box apiBox = await Hive.openBox("apibox");
      await apiBox.put("apikey", newAPIKey);
      await apiBox.put("baseUrl", newBaseUrl);
      await apiBox.put("model", newModel);
      await apiBox.put("enableChineseTranslation", enableChineseTranslation);
      await Hive.close();
      
      // Update the state to reflect saved values
      setState(() {
        apiKey = newAPIKey;
        baseUrl = newBaseUrl;
        model = newModel;
      });
    }
    widget.configAPIKey();
  }

  void clearAPIKey() async {
    apiKey = "";
    Box apiBox = await Hive.openBox("apibox");
    await apiBox.put("apikey", "");
    await apiBox.put("enableChineseTranslation", false);
    await Hive.close();
    widget.configAPIKey();
  }

  void getSavedAPIKey() async {
    Box apiBox = await Hive.openBox("apibox");
    apiKey = await apiBox.get("apikey") ?? "";
    baseUrl = await apiBox.get("baseUrl") ?? "";
    model = await apiBox.get("model") ?? "";
    enableChineseTranslation = await apiBox.get("enableChineseTranslation") ?? false;
    await Hive.close();
    setState(() {});
  }

  void saveChineseTranslationSetting() async {
    Box apiBox = await Hive.openBox("apibox");
    await apiBox.put("enableChineseTranslation", enableChineseTranslation);
    await Hive.close();
  }

  void loadAPIConfig() async {
    try {
      // Pick JSON file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.bytes != null) {
        // Read file content
        Uint8List fileBytes = result.files.single.bytes!;
        String jsonString = utf8.decode(fileBytes);
        
        // Parse JSON
        Map<String, dynamic> config = jsonDecode(jsonString);
        
        // Extract values with null safety
        String loadedApiKey = config['apikey'] ?? config['apiKey'] ?? config['api_key'] ?? '';
        String loadedBaseUrl = config['baseUrl'] ?? config['baseURL'] ?? config['base_url'] ?? '';
        String loadedModel = config['model'] ?? config['modelName'] ?? config['model_name'] ?? '';
        
        // Update controllers and state
        apiKeyController.text = loadedApiKey;
        baseUrlController.text = loadedBaseUrl;
        modelController.text = loadedModel;
        
        setState(() {
          apiKey = loadedApiKey;
          baseUrl = loadedBaseUrl;
          model = loadedModel;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API configuration loaded successfully!')),
        );
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading configuration: ${e.toString()}')),
      );
    }
  }



  @override
  void initState() {
    super.initState();
    getSavedAPIKey();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 10.0,
            ),
            child: const Text(
              "\nTo use this feature please configure your API settings here.",
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 18.0),
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
              controller: apiKeyController,
              cursorColor: ThemeProvider.themeOf(context).id == "dark_theme"
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
                hintText: apiKey == "" ? 'enter API key here..' : apiKey,
                hintStyle: TextStyle(color: Colors.grey[700]),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 18.0, top: 10.0),
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
              controller: baseUrlController,
              cursorColor: ThemeProvider.themeOf(context).id == "dark_theme"
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
                hintText: baseUrl == "" ? 'enter base URL here..' : baseUrl,
                hintStyle: TextStyle(color: Colors.grey[700]),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 18.0, top: 10.0),
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
              controller: modelController,
              cursorColor: ThemeProvider.themeOf(context).id == "dark_theme"
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
                hintText: model == "" ? 'enter model name here..' : model,
                hintStyle: TextStyle(color: Colors.grey[700]),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 18.0, top: 15.0),
            child: Row(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    unselectedWidgetColor: ThemeProvider.themeOf(context).id == "dark_theme"
                        ? Colors.white
                        : Colors.black,
                  ),
                  child: Checkbox(
                    value: enableChineseTranslation,
                    onChanged: (bool? value) {
                      setState(() {
                        enableChineseTranslation = value ?? false;
                      });
                      // Save the checkbox state immediately when changed
                      saveChineseTranslationSetting();
                    },
                    activeColor: ThemeProvider.themeOf(context).id == "dark_theme"
                        ? Colors.white
                        : ThemeProvider.themeOf(context).id == "mixed_theme"
                            ? const Color(0xff121212)
                            : ThemeProvider.themeOf(context).data.primaryColor,
                    checkColor: Colors.blue,
                    side: BorderSide(
                      color: ThemeProvider.themeOf(context).id == "dark_theme"
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
                Text(
                  'Enable Chinese Translation',
                  style: TextStyle(
                    color: ThemeProvider.themeOf(context).id == "dark_theme"
                        ? Colors.white
                        : Colors.black,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  saveAPIKey();
                },
                child: Container(
                  margin: const EdgeInsets.only(
                    top: 10.0,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 7.0),
                  decoration: BoxDecoration(
                    color: ThemeProvider.themeOf(context)
                            .data
                            .textTheme
                            .bodyLarge
                            ?.color
                            ?.withAlpha(12) ??
                        Colors.grey[100],
                    border: Border.all(
                      color: ThemeProvider.themeOf(context).id == "dark_theme"
                          ? Colors.white30
                          : const Color.fromARGB(255, 0, 0, 0)!,
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Text("Save API Key"),
                ),
              ),
              const SizedBox(width: 10.0),
              GestureDetector(
                onTap: () {
                  clearAPIKey();
                },
                child: Container(
                  margin: const EdgeInsets.only(
                    top: 10.0,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 7.0),
                  decoration: BoxDecoration(
                    color: ThemeProvider.themeOf(context)
                            .data
                            .textTheme
                            .bodyLarge
                            ?.color
                            ?.withAlpha(12) ??
                        Colors.grey[100],
                    border: Border.all(
                      color: ThemeProvider.themeOf(context).id == "dark_theme"
                          ? Colors.white30
                          : Colors.grey[500]!,
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Text("Clear API Key"),
                ),
              ),
              const SizedBox(width: 10.0),
              GestureDetector(
                onTap: () {
                  loadAPIConfig();
                },
                child: Container(
                  margin: const EdgeInsets.only(
                    top: 10.0,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 7.0),
                  decoration: BoxDecoration(
                    color: ThemeProvider.themeOf(context)
                            .data
                            .textTheme
                            .bodyLarge
                            ?.color
                            ?.withAlpha(12) ??
                        Colors.grey[100],
                    border: Border.all(
                      color: ThemeProvider.themeOf(context).id == "dark_theme"
                          ? Colors.white30
                          : Colors.grey[500]!,
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Text("Load API Config"),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.only(
              top: 80.0,
              left: 40.0,
              right: 40.0,
            ),
            child: Text(
              "Please configure your API settings above. Make sure to enter a valid API key, base URL (if needed), and model name for your AI service.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500]!,
                fontSize: 13.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
