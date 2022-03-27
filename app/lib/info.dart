import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
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

Future<String> fetchBirdBlurb(String id) async {
  String url = 'https://avibase.bsc-eoc.org/species.jsp?lang=EN&avibaseid=$id';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    var doc = parse(response.body);
    for (var p in doc.getElementsByTagName('p')) {
      print(p.text);
    }
  }
  return "";
}

Future<String> fetchBirdID(Future<Bird> birdFuture) async {
  Bird bird = await birdFuture;
  String encodedName = bird.sciName.replaceAll(' ', '+');
  String searchUrl = "https://avibase.bsc-eoc.org/search.jsp?qstr=$encodedName";

  final response = await http.get(Uri.parse(searchUrl));
  if (response.statusCode == 200) {
    var page = parse(response.body);
    var tables = page.getElementsByTagName('td');
    RegExp idRegex = RegExp(r'[0123456789ABCDEF]{16}');
    RegExpMatch? match;
    for (var t in tables) {
      match = idRegex.firstMatch(t.innerHtml);
      if (match != null) {
        return match.group(0) as String;
      }
    }
  }
  return "";
}

Future<Bird> deferredBird() async {
  return const Bird(
      comName: 'American crow',
      sciName: 'Oenanthe cypriaca',
      spCode: 'amecro',
      howMany: 0,
      obsDt: 'now');
}

void main() async {
  String id = await fetchBirdID(deferredBird());
  print(id);
  print(fetchBirdBlurb(id));
}
