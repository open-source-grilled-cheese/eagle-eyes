import 'dart:convert';

import 'package:http/http.dart' as http;
import 'bird.dart';

Future<String> fetchBirdInfo(Future<Bird> birdFuture) async {
  Bird bird = await birdFuture;
  String url =
      'https://en.wikipedia.org/w/api.php?action=query&format=json&prop=extracts&generator=prefixsearch&exintro=1&explaintext=1&gpssearch=';
  final response =
      await http.get(Uri.parse(url + Uri.encodeComponent(bird.comName)));
  if (response.statusCode == 200) {
    Map<String, dynamic> pages = jsonDecode(response.body)['query']['pages'];
    for (var page in pages.values) {
      return page['extract'] as String;
    }
  }
  return "";
}
