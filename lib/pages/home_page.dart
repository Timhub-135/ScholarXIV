// ignore_for_file: file_names
import 'dart:math';
import 'package:arxiv/apis/arxiv.dart';
import 'package:arxiv/components/each_paper_card.dart';
import 'package:arxiv/components/loading_indicator.dart';
import 'package:arxiv/components/search_box.dart';
import 'package:arxiv/models/paper.dart';
import 'package:arxiv/pages/ai_chat_page.dart';
import 'package:arxiv/pages/bookmarks_page.dart';
import 'package:arxiv/pages/chat_history_page.dart';
import 'package:arxiv/pages/how_to_use.dart';
import 'package:arxiv/pages/pdf_viewer.dart';
import 'package:arxiv/services/state_persistence.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:theme_provider/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ionicons/ionicons.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var sourceCodeURL = "https://github.com/dagmawibabi/ScholArxiv";
  int startPagination = 0;
  int maxContent = 30; // Kept for compatibility, but using maxResults now
  int paginationGap = 30;
  var pdfBaseURL = "https://arxiv.org/pdf";
  bool sortOrderNewest = true;

  var isHomeScreenLoading = true;
  TextEditingController searchTermController = TextEditingController();

  var dio = Dio();
  List<Paper> data = [];
  
  // Topic selection
  List<String> selectedTopics = [];
  bool showTopicSelection = false;
  bool useLatestPapers = true; // Default to latest papers
  int maxResults = 30; // Default max results

  Future<void> search({bool? resetPagination}) async {
    if (resetPagination == true) {
      startPagination = 0;
    }
    isHomeScreenLoading = true;
    data = [];
    setState(() {});

    var searchTerm = searchTermController.text.toString().trim();
    if (searchTerm.isNotEmpty) {
      data = await Arxiv.search(
        searchTerm,
        page: startPagination,
        pageSize: maxResults,
      );
    } else if (selectedTopics.isNotEmpty) {
      // Use selected topics instead of random suggestions
      data = await searchWithSelectedTopics();
    } else {
      data = await suggestedPapers();
    }

    isHomeScreenLoading = false;
    setState(() {});
    
    // Save state after loading papers
    await _saveCurrentState();
  }

  Future<void> toggleSortOrder() async {
    setState(() {
      sortOrderNewest = !sortOrderNewest; // Toggle the sorting order
    });
    await sortPapersByDate(); // Apply the sorting after toggling
    // Save state after changing sort order
    await _saveCurrentState();
  }

  Future<void> sortPapersByDate() async {
    if (data.isNotEmpty) {
      // Sort papers based on publishedAt date
      data.sort((a, b) {
        // Parsing the publishedAt date strings into DateTime objects
        DateTime dateA = DateTime.parse(a.publishedAt);
        DateTime dateB = DateTime.parse(b.publishedAt);

        return sortOrderNewest
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      });
      setState(() {});
      // Save state after sorting
      await _saveCurrentState();
    }
  }

  // Save current app state to local storage
  Future<void> _saveCurrentState() async {
    await StatePersistence.saveAppState(
      papers: data,
      searchTerm: searchTermController.text,
      selectedTopics: selectedTopics,
      startPagination: startPagination,
      sortOrderNewest: sortOrderNewest,
      useLatestPapers: useLatestPapers,
      maxResults: maxResults,
    );
  }

  Future<List<Paper>> suggestedPapers() async {
    var maxRetries = 10;
    List<Paper> suggested = [];
    while (suggested.isEmpty && maxRetries > 0) {
      suggested = await Arxiv.suggest(pageSize: maxResults);
      maxRetries--;
    }
    return suggested;
  }

  Future<List<Paper>> searchWithSelectedTopics() async {
    if (selectedTopics.isEmpty) return [];
    
    // Search for papers from selected topics
    List<Paper> allPapers = [];
    
    if (useLatestPapers) {
      // Search all selected topics for latest papers
      for (final topic in selectedTopics) {
        List<Paper> papers = await Arxiv.search(topic, page: startPagination, pageSize: maxResults);
        allPapers.addAll(papers);
      }
      
      // Sort by published date (newest first) and limit to maxResults
      allPapers.sort((a, b) {
        DateTime dateA = DateTime.parse(a.publishedAt);
        DateTime dateB = DateTime.parse(b.publishedAt);
        return dateB.compareTo(dateA); // newest first
      });
      
      return allPapers.take(maxResults).toList();
    } else {
      // Random selection mode (original behavior)
      Random random = Random();
      
      // Try a few random topics from the selected ones
      for (int i = 0; i < min(3, selectedTopics.length); i++) {
        int randomIndex = random.nextInt(selectedTopics.length);
        String topic = selectedTopics[randomIndex];
        
        List<Paper> topicPapers = await Arxiv.search(topic, page: startPagination, pageSize: maxResults ~/ 3);
        allPapers.addAll(topicPapers);
      }
      
      return allPapers;
    }
  }

  var paperTitle = "";
  var savePath = "";
  var pdfURL = "";
  dynamic downloadPath = "";

  Future<void> parseAndLaunchURL(String currentURL, String title) async {
    paperTitle = title;

    var splitURL = currentURL.split("/");
    var id = splitURL[splitURL.length - 1];
    var urlType = 0;
    if (id.contains(".") == true) {
      pdfURL = "$pdfBaseURL/$id";
      urlType = 1;
    } else {
      pdfURL = "$pdfBaseURL/cond-mat/$id";
      urlType = 2;
    }

    final Uri parsedURL = Uri.parse(pdfURL);
    savePath = '${(await getTemporaryDirectory()).path}/paper3.pdf';

    if (urlType == 2) {
      var result = await dio.downloadUri(parsedURL, savePath);
      if (result.statusCode != 200) {}
    }

    Navigator.push(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewer(
          paperTitle: paperTitle,
          savePath: savePath,
          pdfURL: pdfURL,
          urlType: urlType,
          downloadPaper: downloadPaper,
        ),
      ),
    );
    setState(() {});
  }

  void downloadPaper(String paperURL) async {
    var splitURL = paperURL.split("/");
    var id = splitURL[splitURL.length - 1];
    var selectedURL = "";
    if (id.contains(".") == true) {
      selectedURL = "$pdfBaseURL/$id";
    } else {
      selectedURL = "$pdfBaseURL/cond-mat/$id";
    }
    await launchUrl(Uri.parse(selectedURL));
  }

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  // Load saved state on app start
  Future<void> _loadSavedState() async {
    final savedState = await StatePersistence.loadAppState();
    
    if (savedState != null && savedState['papers'] != null) {
      // Restore saved state
      setState(() {
        data = savedState['papers'];
        searchTermController.text = savedState['searchTerm'] ?? '';
        selectedTopics = List<String>.from(savedState['selectedTopics'] ?? []);
        startPagination = savedState['startPagination'] ?? 0;
        sortOrderNewest = savedState['sortOrderNewest'] ?? true;
        useLatestPapers = savedState['useLatestPapers'] ?? true;
        maxResults = savedState['maxResults'] ?? 30;
        isHomeScreenLoading = false;
      });
      
      // Apply sorting if needed
      if (data.isNotEmpty && sortOrderNewest) {
        await sortPapersByDate();
      }
    } else {
      // No saved papers found, but try to load settings first
      if (savedState != null) {
        // Restore settings even if no papers were saved
        setState(() {
          searchTermController.text = savedState['searchTerm'] ?? '';
          selectedTopics = List<String>.from(savedState['selectedTopics'] ?? []);
          useLatestPapers = savedState['useLatestPapers'] ?? true;
          maxResults = savedState['maxResults'] ?? 30;
          sortOrderNewest = savedState['sortOrderNewest'] ?? true;
        });
      }
      
      // Fetch fresh data using the restored settings (or defaults)
      await search();
    }
  }

  @override
  void dispose() {
    searchTermController.dispose();
    super.dispose();
  }

  Widget buildTopicSelection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: ThemeProvider.themeOf(context).data.appBarTheme.backgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Topics',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: ThemeProvider.themeOf(context).id == "light_theme"
                      ? Colors.black
                      : Colors.white,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    showTopicSelection = false;
                  });
                },
                icon: const Icon(Icons.close, size: 20.0),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          
          // Latest/Random Toggle
          Row(
            children: [
              Text(
                'Selection Mode:',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: ThemeProvider.themeOf(context).id == "light_theme"
                      ? Colors.black
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 12.0),
              ChoiceChip(
                label: const Text('Latest Papers'),
                selected: useLatestPapers,
                onSelected: (selected) {
                  setState(() {
                    useLatestPapers = true;
                  });
                  // Save state after changing selection mode
                  _saveCurrentState();
                },
              ),
              const SizedBox(width: 8.0),
              ChoiceChip(
                label: const Text('Random'),
                selected: !useLatestPapers,
                onSelected: (selected) {
                  setState(() {
                    useLatestPapers = false;
                  });
                  // Save state after changing selection mode
                  _saveCurrentState();
                },
              ),
            ],
          ),
          
          // Max Results Input
          Row(
            children: [
              Text(
                'Max Results:',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: ThemeProvider.themeOf(context).id == "light_theme"
                      ? Colors.black
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 12.0),
              SizedBox(
                width: 80.0,
                child: TextField(
                  controller: TextEditingController(text: maxResults.toString()),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    final newMax = int.tryParse(value) ?? 30;
                    setState(() {
                      maxResults = newMax.clamp(1, 100); // Limit between 1 and 100
                    });
                    // Save state after changing max results
                    _saveCurrentState();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: Arxiv.topics.map((topic) {
              bool isSelected = selectedTopics.contains(topic);
              return FilterChip(
                label: Text(topic),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      selectedTopics.add(topic);
                    } else {
                      selectedTopics.remove(topic);
                    }
                  });
                  // Save state after changing topic selection
                  _saveCurrentState();
                },
                backgroundColor: Colors.grey[300],
                selectedColor: ThemeProvider.themeOf(context).id == "light_theme"
                    ? Colors.blue[300]
                    : Colors.blue[600],
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (ThemeProvider.themeOf(context).id == "light_theme"
                          ? Colors.black
                          : Colors.white),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedTopics.clear();
                  });
                  // Save state after clearing topics
                  _saveCurrentState();
                },
                child: const Text('Clear All'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedTopics = List.from(Arxiv.topics);
                  });
                  // Save state after selecting all topics
                  _saveCurrentState();
                },
                child: const Text('Select All'),
              ),
            ],
          ),
          if (selectedTopics.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            ElevatedButton(
              onPressed: () {
                search(resetPagination: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeProvider.themeOf(context).id == "light_theme"
                    ? Colors.blue
                    : Colors.blue[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40.0),
              ),
              child: const Text('Search Selected Topics'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            ThemeProvider.themeOf(context).data.appBarTheme.backgroundColor,
        title: const Text(
          "ScholArxiv",
        ),
        actions: [
          // TOPIC SELECTION
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    showTopicSelection = !showTopicSelection;
                  });
                },
                icon: const Icon(
                  Icons.topic_outlined,
                ),
              ),
              if (selectedTopics.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      '${selectedTopics.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // HELP
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HowToUsePage(),
                ),
              );
            },
            icon: const Icon(
              Icons.help_outline,
            ),
          ),

          // BOOKMARKS
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookmarksPage(
                    downloadPaper: downloadPaper,
                    parseAndLaunchURL: parseAndLaunchURL,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.bookmark_border_outlined,
            ),
          ),

          // CHAT HISTORY
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatHistoryPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.history,
            ),
          ),

          // CHANGE THEME
          IconButton(
            onPressed: () {
              ThemeProvider.controllerOf(context).nextTheme();
            },
            icon: Icon(
              ThemeProvider.themeOf(context).id == "light_theme"
                  ? Icons.dark_mode_outlined
                  : ThemeProvider.themeOf(context).id == "dark_theme"
                      ? Icons.sunny_snowing
                      : Ionicons.sunny,
            ),
          ),

          // CHAT WITH AI
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIChatPage(
                    paperData: null,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.auto_awesome_outlined,
            ),
          ),

          const SizedBox(width: 10.0),
        ],
      ),
      body: LiquidPullToRefresh(
        onRefresh: search,
        backgroundColor: Colors.white,
        color: const Color(0xff121212),
        animSpeedFactor: 2.0,
        child: ListView(
          children: [
            SearchBox(
                searchTermController: searchTermController,
                searchFunction: search,
                toggleSortOrder: toggleSortOrder,
                sortOrderNewest: sortOrderNewest),
            
            // TOPIC STATUS INDICATOR
            if (selectedTopics.isNotEmpty && !showTopicSelection)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.topic,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                          'Searching ${selectedTopics.length} topic${selectedTopics.length == 1 ? "" : "s"} (${useLatestPapers ? "Latest" : "Random"}, Max: $maxResults)',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedTopics.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            
            // Topic Selection Widget
            if (showTopicSelection) buildTopicSelection(),

            // Data or Loading
            isHomeScreenLoading == true
                ? const LoadingIndicator(
                    topPadding: 200.0,
                  )
                : data.isNotEmpty
                    ? Column(
                        children: data.map(
                          (eachPaper) {
                            return EachPaperCard(
                              eachPaper: eachPaper,
                              downloadPaper: downloadPaper,
                              parseAndLaunchURL: parseAndLaunchURL,
                              isBookmarked: false,
                            );
                          },
                        ).toList(),
                      )
                    : const Padding(
                        padding: EdgeInsets.only(top: 200.0),
                        child: Center(
                          child: Text(
                            "No Results Found!",
                          ),
                        ),
                      ),

            const SizedBox(
              height: 20.0,
            ),

            // Pagination
            data.isNotEmpty && searchTermController.text.trim() != ""
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (startPagination >= paginationGap) {
                            startPagination -= paginationGap;
                            search();
                          }
                        },
                        icon: Icon(
                          Ionicons.arrow_back,
                          color: startPagination < paginationGap
                              ? Colors.white
                              : Colors.grey[400]!,
                          size: 20.0,
                        ),
                      ),
                      Text(
                        "Showing results from $startPagination to ${startPagination + maxResults}",
                        style: TextStyle(
                          color: Colors.grey[600]!,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          startPagination += paginationGap;
                          search();
                        },
                        icon: Icon(
                          Ionicons.arrow_forward,
                          color: Colors.grey[400]!,
                          size: 20.0,
                        ),
                      ),
                    ],
                  )
                : Container(),

            // Container(
            //   width: 100.0,
            //   padding: const EdgeInsets.only(top: 200.0, bottom: 40.0),
            //   child: Center(
            //     child: Text(
            //       "Thank you to arXiv for use of its \nopen access interoperability.",
            //       textAlign: TextAlign.center,
            //       style: TextStyle(
            //         color: Colors.grey[400]!,
            //         fontSize: 12.0,
            //       ),
            //     ),
            //   ),
            // ),
            // Center(
            //   child: GestureDetector(
            //     onTap: () {
            //       launchUrl(Uri.parse(sourceCodeURL));
            //     },
            //     child: const Text(
            //       "View Source Code on GitHub",
            //       textAlign: TextAlign.center,
            //       style: TextStyle(
            //         color: Colors.blueAccent,
            //         fontSize: 12.0,
            //       ),
            //     ),
            //   ),
            // ),

            // Center(
            //   child: Padding(
            //     padding: const EdgeInsets.only(top: 5.0),
            //     child: Text(
            //       "Made with 🤍 by Dream Intelligence",
            //       textAlign: TextAlign.center,
            //       style: TextStyle(
            //         color: Colors.grey[600]!,
            //         fontSize: 12.0,
            //       ),
            //     ),
            //   ),
            // ),

            const SizedBox(
              height: 20.0,
            ),
          ],
        ),
      ),
    );
  }
}
