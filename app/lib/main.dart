import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'bird.dart';
import 'photos.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

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

Future<List<Bird>> fetchAlbum() async {
  final response = await http.get(
    Uri.parse('https://api.ebird.org/v2/data/obs/IN/recent'),
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
    return Future<List<Bird>>.value(jsonObjs);
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load album');
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late GoogleMapController mapController;
  late AnimationController controller;

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

  late Future<List<Bird>> futureAlbum;

  @override
  void initState() {
    super.initState();
    futureAlbum = fetchAlbum();
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
            FutureBuilder<List<Bird>>(
              future: futureAlbum,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return BirdNameCard(bird: snapshot.data![2]);
                } else if (snapshot.hasError) {
                  return Text('${snapshot.error}');
                }
                // By default, show a loading spinner.
                return const CircularProgressIndicator();
              },
            ),
            FutureBuilder<List<Bird>>(
              future: futureAlbum,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return BirdPhotoCarousel(bird: snapshot.data![2]);
                } else if (snapshot.hasError) {
                  return Text('${snapshot.error}');
                }
                // By default, show a loading spinner.
                return const CircularProgressIndicator();
              },
            ),
            // Bird Photo
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

class BirdNameCard extends StatelessWidget {
  final Bird bird;
  const BirdNameCard({Key? key, required this.bird}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: <Widget>[
            Text(
              bird.comName,
              textScaleFactor: 2.0,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              bird.sciName,
              textScaleFactor: 1.5,
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: FontStyle.italic),
            )
          ],
        ),
      ),
    );
  }
}

class BirdPhotoCarousel extends StatefulWidget {
  final Bird bird;
  const BirdPhotoCarousel({Key? key, required this.bird}) : super(key: key);

  @override
  State<BirdPhotoCarousel> createState() => _BirdPhotoCarouselState();
}

class _BirdPhotoCarouselState extends State<BirdPhotoCarousel> {
  late Future<List<String>> imageLinks;

  @override
  void initState() {
    super.initState();
    imageLinks = fetchBirdPhotos(widget.bird, 3);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        child: FutureBuilder<List<String>>(
            future: imageLinks,
            builder: (context, snapshot) {
              List<String> links;
              if (snapshot.hasData) {
                links = snapshot.data!;
              } else {
                links = [
                  'https://media2.giphy.com/media/3oEjI6SIIHBdRxXI40/200w.gif?cid=82a1493b888pllhrj3fgn9h5qtcid63crmatt4rfjk7s3j37&rid=200w.gif&ct=g'
                ];
              }
              return CarouselSlider(
                options: CarouselOptions(height: 300.0, viewportFraction: 0.9),
                items: links.map((link) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Image(image: NetworkImage(link));
                    },
                  );
                }).toList(),
              );
            }));
  }
}
