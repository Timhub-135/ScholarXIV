import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:arxiv/models/paper.dart';

class StatePersistence {
  static const String _boxName = 'app_state';
  static const String _papersKey = 'cached_papers';
  static const String _searchTermKey = 'search_term';
  static const String _selectedTopicsKey = 'selected_topics';
  static const String _startPaginationKey = 'start_pagination';
  static const String _sortOrderKey = 'sort_order_newest';
  static const String _useLatestPapersKey = 'use_latest_papers';
  static const String _maxResultsKey = 'max_results';

  static Future<void> saveAppState({
    required List<Paper> papers,
    required String searchTerm,
    required List<String> selectedTopics,
    required int startPagination,
    required bool sortOrderNewest,
    required bool useLatestPapers,
    required int maxResults,
  }) async {
    try {
      final box = await Hive.openBox(_boxName);
      
      // Convert papers to JSON for storage
      final papersJson = papers.map((paper) => paper.toJson()).toList();
      
      await box.put(_papersKey, jsonEncode(papersJson));
      await box.put(_searchTermKey, searchTerm);
      await box.put(_selectedTopicsKey, selectedTopics);
      await box.put(_startPaginationKey, startPagination);
      await box.put(_sortOrderKey, sortOrderNewest);
      await box.put(_useLatestPapersKey, useLatestPapers);
      await box.put(_maxResultsKey, maxResults);
      
      await box.close();
    } catch (e) {
      // Handle error saving app state
    }
  }

  static Future<Map<String, dynamic>?> loadAppState() async {
    try {
      final box = await Hive.openBox(_boxName);
      
      final papersJson = box.get(_papersKey);
      final searchTerm = box.get(_searchTermKey) ?? '';
      final selectedTopics = List<String>.from(box.get(_selectedTopicsKey) ?? []);
      final startPagination = box.get(_startPaginationKey) ?? 0;
      final sortOrderNewest = box.get(_sortOrderKey) ?? true;
      final useLatestPapers = box.get(_useLatestPapersKey) ?? true;
      final maxResults = box.get(_maxResultsKey) ?? 30;
      
      List<Paper> papers = [];
      if (papersJson != null) {
        try {
          final decodedPapers = jsonDecode(papersJson) as List;
          papers = decodedPapers.map((json) => Paper.fromJson(json)).toList();
        } catch (e) {
          // Handle error parsing cached papers
        }
      }
      
      await box.close();
      
      return {
        'papers': papers,
        'searchTerm': searchTerm,
        'selectedTopics': selectedTopics,
        'startPagination': startPagination,
        'sortOrderNewest': sortOrderNewest,
        'useLatestPapers': useLatestPapers,
        'maxResults': maxResults,
      };
    } catch (e) {
      // Handle error loading app state
      return null;
    }
  }

  static Future<void> clearAppState() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.clear();
      await box.close();
    } catch (e) {
      // Handle error clearing app state
    }
  }
}