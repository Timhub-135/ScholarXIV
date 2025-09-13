import 'dart:convert';
import 'dart:math';

import 'package:arxiv/models/paper.dart';
import 'package:dio/dio.dart';
import 'package:xml2json/xml2json.dart';

class Arxiv {
  static const _baseUrl = "http://export.arxiv.org/api/query?search_query=all";

  static final _dio = Dio();

  static const _topics = [
    "computer",
    "machine learning",
    "mathematical theory of communication",
    "neural network",
    "Computational Engineering",
    "Formal Languages and Automata Theory",
    "Hardware Architecture",
    "Networking and Internet Architecture",
  ];

  /// Fetches papers for the requested [term].
  /// [page] and [pageSize] are optional. If missing, 0 and 30 are used as defaults respectively.
  static Future<List<Paper>> search(
    String term, {
    int page = 0,
    int pageSize = 30,
  }) async {
    final xml2json = Xml2Json();

    try {
      var response = await _dio.get(
        "$_baseUrl:$term&start=$page&max_results=$pageSize",
      );
      xml2json.parse(response.data);
      var jsonData = await json.decode(xml2json.toParker());
      return jsonData["feed"]["entry"].map<Paper>((entry) => Paper.fromJson(entry)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches papers for a random topic.
  static Future<List<Paper>> suggest({int pageSize = 30}) {
    Random random = Random();
    int randomIndex = random.nextInt(_topics.length);
    String topic = _topics[randomIndex];

    return search(topic, pageSize: pageSize);
  }
}
