// ignore_for_file: file_names
import 'package:arxiv/models/paper.dart';
import 'package:arxiv/pages/full_screen_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:hive/hive.dart';
import 'package:ionicons/ionicons.dart';
import 'package:theme_provider/theme_provider.dart';
import 'package:arxiv/apis/gemini.dart';

class SummaryBottomSheet extends StatefulWidget {
  const SummaryBottomSheet({
    super.key,
    required this.paperData,
    required this.parseAndLaunchURL,
  });

  final Paper paperData;
  final Function parseAndLaunchURL;

  @override
  State<SummaryBottomSheet> createState() => _SummaryBottomSheetState();
}

class _SummaryBottomSheetState extends State<SummaryBottomSheet> with SingleTickerProviderStateMixin {
  var tts = FlutterTts();
  var isSpeaking = false;
  var summary = "";
  var speedRate = 0.5;
  var speedFactor = 0.1;
  String chineseTranslation = "";
  bool isTranslating = false;
  bool enableChineseTranslation = false;
  late AnimationController _cursorController;
  late Animation<double> _cursorAnimation;

  void readSummary() async {
    if (isSpeaking == false) {
      await tts.setLanguage("en-US");
      tts.speak(summary);
    } else {
      tts.stop();
    }
    isSpeaking = !isSpeaking;
    setState(() {});
  }

  void changeSpeedRate({bool? increase}) async {
    if (increase == true) {
      if (speedRate < 0.9) {
        speedRate += speedFactor;
      }
    } else {
      if (speedRate >= 0.1) {
        speedRate -= speedFactor;
      }
    }
    tts.stop();
    tts.setSpeechRate(speedRate);
    isSpeaking = false;
    readSummary();
    final box = await Hive.openBox("speedRateBox");
    box.put("speedRate", speedRate);
    await Hive.close();
  }

  void getSpeedRate() async {
    final box = await Hive.openBox("speedRateBox");
    speedRate = await box.get("speedRate");
    await Hive.close();
    tts.setSpeechRate(speedRate);
  }

  void resetSpeechRate() async {
    speedRate = 0.5;
    final box = await Hive.openBox("speedRateBox");
    box.put("speedRate", speedRate);
    await Hive.close();
    tts.stop();
    tts.setSpeechRate(speedRate);
    isSpeaking = false;
    readSummary();
  }

  @override
  void initState() {
    super.initState();
    getSpeedRate();
    
    // Reset chineseTranslation to ensure fresh translation for this paper
    chineseTranslation = "";
    
    loadChineseTranslationPreference();
    
    // Initialize cursor animation for typing effect
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cursorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cursorController,
        curve: Curves.easeInOut,
      ),
    );
    _cursorController.repeat(reverse: true);
    
    tts.setCompletionHandler(() {
      isSpeaking = false;
      setState(() {});
    });
    summary = widget.paperData.summary;
  }

  void loadChineseTranslationPreference() async {
    Box apiBox = await Hive.openBox("apibox");
    enableChineseTranslation = await apiBox.get("enableChineseTranslation") ?? false;
    await Hive.close();
    
    // Reset chineseTranslation to ensure fresh translation for this paper
    chineseTranslation = "";
    
    setState(() {});
    
    if (enableChineseTranslation) {
      fetchChineseTranslation();
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  void fetchChineseTranslation() async {
    if (isTranslating || chineseTranslation.isNotEmpty) return;
    
    setState(() {
      isTranslating = true;
      chineseTranslation = ""; // Start with empty translation for streaming
    });
    
    try {
      var gemini = await Gemini.newModel(paper: widget.paperData);
      
      await gemini.translateToChineseStream(widget.paperData.summary, (String chunk) {
        setState(() {
          chineseTranslation += chunk;
        });
      });
      
      setState(() {
        isTranslating = false;
      });
    } catch (e) {
      setState(() {
        chineseTranslation = "Translation failed: ${e.toString()}";
        isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String summary = widget.paperData.summary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: ThemeProvider.themeOf(context).data.textTheme.bodyLarge?.color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(top: 1.0),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: ThemeProvider.themeOf(context).data.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                clipBehavior: Clip.hardEdge,
                margin: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  color: ThemeProvider.themeOf(context).id == "mixed_theme"
                      ? const Color(0xff121212)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 5.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Summary",
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color:
                              ThemeProvider.themeOf(context).id == "mixed_theme"
                                  ? Colors.white
                                  : ThemeProvider.themeOf(context)
                                      .data
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          isSpeaking == true
                              ? Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        if (speedRate > 0.0) {
                                          changeSpeedRate(increase: false);
                                        }
                                      },
                                      icon: Icon(
                                        Icons.remove,
                                        color:
                                            ThemeProvider.themeOf(context).id ==
                                                    "mixed_theme"
                                                ? Colors.grey[200]
                                                : ThemeProvider.themeOf(context)
                                                    .data
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        resetSpeechRate();
                                      },
                                      child: Text(
                                        speedRate.toStringAsFixed(1).toString(),
                                        style: TextStyle(
                                          color: ThemeProvider.themeOf(context)
                                                      .id ==
                                                  "mixed_theme"
                                              ? Colors.grey[200]
                                              : ThemeProvider.themeOf(context)
                                                  .data
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        if (speedRate < 1.0) {
                                          changeSpeedRate(increase: true);
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.add,
                                      ),
                                    )
                                  ],
                                )
                              : Container(),
                          IconButton(
                            onPressed: () {
                              readSummary();
                            },
                            icon: Icon(
                              isSpeaking == true
                                  ? Ionicons.stop_outline
                                  : Ionicons.volume_high_outline,
                              // color: Colors.white,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: IconButton(
                              onPressed: () {
                                widget.parseAndLaunchURL(
                                  widget.paperData.id,
                                  widget.paperData.title,
                                );
                              },
                              icon: const Icon(
                                Ionicons.open_outline,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenSummaryPage(
                                    paperData: widget.paperData,
                                    parseAndLaunchURL: widget.parseAndLaunchURL,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Ionicons.expand_outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.47,
                width: double.infinity,
                child: ListView(
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(
                          left: 20.0,
                          right: 20.0,
                          top: 10.0,
                          bottom: 20.0,
                        ),
                        child: (Paper.containsLatex(summary)
                            ? TeXView(
                                child: TeXViewDocument(
                                  summary,
                                  style: TeXViewStyle(
                                    contentColor: ThemeProvider.themeOf(context)
                                        .data
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                    textAlign: TeXViewTextAlign.left,
                                    fontStyle: TeXViewFontStyle(
                                        fontSize: 15,
                                        fontWeight: TeXViewFontWeight.normal),
                                  ),
                                ),
                              )
                            : SelectableText(
                                summary,
                                style: const TextStyle(
                                  fontSize: 15.0,
                                ),
                              ))),
                    
                    // Chinese Translation Section
                    if (enableChineseTranslation && chineseTranslation.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(
                          left: 20.0,
                          right: 20.0,
                          bottom: 20.0,
                        ),
                        padding: const EdgeInsets.all(15.0),
                        decoration: BoxDecoration(
                          color: ThemeProvider.themeOf(context).id == "mixed_theme"
                              ? const Color(0xff1e1e1e)
                              : ThemeProvider.themeOf(context)
                                  .data
                                  .primaryColor
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: ThemeProvider.themeOf(context).id == "mixed_theme"
                                ? Colors.grey[800]!
                                : ThemeProvider.themeOf(context)
                                    .data
                                    .primaryColor
                                    .withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.translate,
                                  size: 16,
                                  color: ThemeProvider.themeOf(context).id == "mixed_theme"
                                      ? Colors.grey[300]
                                      : ThemeProvider.themeOf(context)
                                          .data
                                          .primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "中文翻译",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeProvider.themeOf(context).id == "mixed_theme"
                                        ? Colors.grey[300]
                                        : ThemeProvider.themeOf(context)
                                            .data
                                            .primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            isTranslating
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SelectableText(
                                        chineseTranslation,
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          color: ThemeProvider.themeOf(context).id == "mixed_theme"
                                              ? Colors.grey[200]
                                              : ThemeProvider.themeOf(context)
                                                  .data
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          AnimatedBuilder(
                                            animation: _cursorAnimation,
                                            builder: (context, child) {
                                              return Container(
                                                width: 2,
                                                height: 16,
                                                color: _cursorAnimation.value > 0.5
                                                    ? (ThemeProvider.themeOf(context).id == "mixed_theme"
                                                        ? Colors.grey[300]
                                                        : ThemeProvider.themeOf(context)
                                                            .data
                                                            .primaryColor)
                                                    : Colors.transparent,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Translating...",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: ThemeProvider.themeOf(context).id == "mixed_theme"
                                                  ? Colors.grey[400]
                                                  : ThemeProvider.themeOf(context)
                                                      .data
                                                      .primaryColor
                                                      .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : SelectableText(
                                    chineseTranslation,
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      color: ThemeProvider.themeOf(context).id == "mixed_theme"
                                          ? Colors.grey[200]
                                          : ThemeProvider.themeOf(context)
                                              .data
                                              .textTheme
                                              .bodyLarge
                                              ?.color,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 60.0), // Bottom padding for scroll
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
