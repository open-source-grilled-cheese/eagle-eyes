import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'bird.dart';

Future<List<String>> fetchBirdPhotos(Bird bird, int numImages) async {
  String catalogUrl = "https://ebird.org/media/catalog.csv?taxonCode=";
  String assetUrl = "https://cdn.download.ams.birds.cornell.edu/api/v1/asset/";
  final response =
      await http.get(Uri.parse(catalogUrl + Uri.encodeComponent(bird.spCode)));
  if (response.statusCode == 200) {
    List<List<dynamic>> catalog = const CsvToListConverter(
      eol: '\n',
    ).convert(response.body);
    catalog.removeAt(0);
    List<String> provisionalLinks = catalog
        .take(numImages)
        .map((e) => assetUrl + (e[0].toString()))
        .toList();
    List<String> links = [];
    for (var link in provisionalLinks) {
      try {
        NetworkImage(link);
      } on Exception catch (e) {
        print("$e: failed to load $link");
        continue;
      }
      links.add(link);
    }
    return links;
  }

  return [
    "https://www.how-to-draw-funny-cartoons.com/images/cartoon-bird-007.jpg"
  ];
}

class WikiFile {
  final String name;
  final String id;

  WikiFile(this.name, this.id);

  WikiFile.fromJson(Map<String, dynamic> json)
      : name = json['title'],
        id = json['pageid'].toString();

  Map<String, dynamic> toJson() => {
        'title': name,
        'pageid': id,
      };
}

Future<List<String>> wikiFetchBirdPhotos(String name) async {
  String url =
      'https://commons.wikimedia.org/w/api.php?action=query&format=json&list=search&srnamespace=6|0&srsearch=';
  final response = await http.get(Uri.parse(url + Uri.encodeComponent(name)));
  if (response.statusCode == 200) {
    Map<String, dynamic> json = jsonDecode(response.body);
    // List<WikiFile> filenames = json['query']['search']
    //     .toList()
    //     .map((entry) => WikiFile.fromJson(entry));
    List<String> urls = [];
    for (var e in json['query']['search']) {
      WikiFile file = WikiFile.fromJson(e);
      if (file.name.startsWith('File:')) {
        urls.add(await wikiFetchPhotoUrl(file));
      }
    }
    return urls;
  }

  return [
    "https://www.how-to-draw-funny-cartoons.com/images/cartoon-bird-007.jpg"
  ];
}

Future<String> wikiFetchPhotoUrl(WikiFile file) async {
  String url =
      'https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url&titles=';
  final response =
      await http.get(Uri.parse(url + Uri.encodeComponent(file.name)));
  if (response.statusCode == 200) {
    Map<String, dynamic> json = jsonDecode(response.body);
    // print(json['query']['pages'][file.id]);
    return json['query']['pages'][file.id]['imageinfo'][0]['url'].toString();
  } else {
    return "";
  }
}
