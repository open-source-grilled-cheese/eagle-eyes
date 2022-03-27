import 'package:http/http.dart' as http;
import 'dart:developer';
import 'dart:convert';

Future<String> fetchAudioURL(String name) async {
  String url = "https://www.xeno-canto.org/api/2/recordings?query=";
  final response = await http.get(Uri.parse(url + Uri.encodeComponent(name)));
  log(response.statusCode.toString());

  if (response.statusCode == 200) {
    Map<String, dynamic> data = jsonDecode(response.body);
    if (data['numRecordings'] == 0) {
      log("no recording found for bird");
    } else {
      for (var r in data['recordings']) {
        if (r['quality'] == "A") {
          return r['file'];
        }
      }
      // none ranked A, so just give first
      return data['recordings'][0]
          ['file']; // gets the first call (they are sorted by quality)
    }
  }

  // did not work: return moo
  return 'https://www.applesaucekids.com/sound%20effects/moo.mp3';
}
