import 'dart:convert';

import 'package:http/http.dart' as http;

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

Future<List<String>> fetchBirdPhotos(String name) async {
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
        urls.add(await fetchPhotoUrl(file));
      }
    }
    return urls;
  }

  return [
    "https://www.how-to-draw-funny-cartoons.com/images/cartoon-bird-007.jpg"
  ];
}

Future<String> fetchPhotoUrl(WikiFile file) async {
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
