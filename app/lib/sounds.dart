import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> fetchAudioURL(String name) async {
  String url = "https://www.xeno-canto.org/api/2/recordings?query=";
  final response = await http.get(Uri.parse(url + Uri.encodeComponent(name)));
  print(response.statusCode);

  if (response.statusCode == 200) {
    Map<String, dynamic> data = jsonDecode(response.body);
    if (data['numRecordings'] == 0) {
      print("no recording found for bird");
    } else {
      return data['recordings'][0]['file'];
    }
  }

  // did not work: return moo
  return 'https://www.applesaucekids.com/sound%20effects/moo.mp3';
}
