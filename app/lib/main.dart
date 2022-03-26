import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'bird.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.teal,
      ),
      home: const MyHomePage(title: 'Eagle Eyes: Bird of the Day'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

Future<Bird> fetchBirds() async {
  LocationData currLoc = await Location().getLocation();
  double? lat = currLoc.latitude;
  double? lng = currLoc.longitude;
  log("hello people");
  log(lat.toString());
  //"https://api.ebird.org/v2/data/obs/geo/recent/cangoo?lat=$lat&lng=$lng"
  //'https://api.ebird.org/v2/data/obs/geo/recent?lat=$lat&lng=$lng&sort=species&maxResults=10000'
  //'https://api.ebird.org/v2/product/stats/US-OH/2022/3/21'
  final response = await http.get(
    Uri.parse(
        'https://api.ebird.org/v2/data/obs/geo/recent?lat=$lat&lng=$lng&sort=species&maxResults=10000'),
    headers: {
      'X-eBirdApiToken': dotenv.env['EBIRD_API_KEY'] ?? 'API_KEY not found',
    },
  );

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    List<Map<String, dynamic>> responseList =
        (jsonDecode(response.body) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

    List<Bird> jsonObjs =
        responseList.map((resp) => Bird.fromJson(resp)).toList();

    var rng = math.Random();
    late int selectedBird;

    var validBird = false;

    while (!validBird) {
      selectedBird = rng.nextInt(jsonObjs.length);
      validBird = await checkBird(jsonObjs[selectedBird], lat, lng);
      log("testing bird");
      log(selectedBird.toString());
    }

    return jsonObjs[selectedBird];
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    print(response.body);
    throw Exception('Failed to load album');
  }
}

Future<bool> checkBird(Bird bird, double? lat, double? lng) async {
  var speciesCode = bird.spCode;
  final response = await http.get(
    Uri.parse(
        'https://api.ebird.org/v2/data/obs/geo/recent/$speciesCode?lat=$lat&lng=$lng'),
    headers: {
      'X-eBirdApiToken': dotenv.env['EBIRD_API_KEY'] ?? 'API_KEY not found',
    },
  );

  if (response.statusCode == 200) {
    List<Map<String, dynamic>> responseList =
        (jsonDecode(response.body) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

    if (responseList.length < 10) {
      return false;
    } else {
      return true;
    }
  } else {
    print(response.body);
    throw Exception('Failed to look up species');
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late GoogleMapController mapController;
  late AnimationController controller;
  late Future<Bird> futureAlbum;

  void _onMapCreated(GoogleMapController controller) async {
    var location = Location();
    final currentLocation = await location.getLocation();
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
            target:
                LatLng(currentLocation.latitude!, currentLocation.longitude!),
            zoom: 15),
      ),
    );
  }

  void _incrementCounter() {}

  @override
  void initState() {
    super.initState();

    futureAlbum = fetchBirds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: ListView(
          padding: const EdgeInsets.all(12.0),
          children: <Widget>[
            // Bird Name
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: const <Widget>[
                    Text(
                      'Ferruginous Pygmy-Owl',
                      textScaleFactor: 2.0,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Glaucidium brasilianum',
                      textScaleFactor: 1.5,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic),
                    )
                  ],
                ),
              ),
            ),
            FutureBuilder<Bird>(
              future: futureAlbum,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(snapshot.data!.comName);
                } else if (snapshot.hasError) {
                  return Text('${snapshot.error}');
                }

                // By default, show a loading spinner.
                return const CircularProgressIndicator();
              },
            ),
            // Bird Photo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CarouselSlider(
                  options: CarouselOptions(height: 300.0),
                  items: [
                    'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg'
                  ].map((link) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Image(image: NetworkImage(link));
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            // Birdcall Player
            Card(
              child: Row(children: [
                IconButton(
                    onPressed: _incrementCounter,
                    iconSize: 64.0,
                    icon: const Icon(Icons.play_circle)),
              ]),
            ),
            SizedBox(
              height: 500,
              child: Card(
                  child: GoogleMap(
                onMapCreated: _onMapCreated,
                padding: const EdgeInsets.all(8.0),
                myLocationEnabled: true,
                initialCameraPosition:
                    const CameraPosition(target: LatLng(0, 0), zoom: 3),
              )),
            ),
            Text(
              'More Data Here',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
    );
  }
}
