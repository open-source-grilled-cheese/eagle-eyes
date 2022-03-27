import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:after_layout/after_layout.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'bird.dart';
import 'photos.dart';
import 'sounds.dart' as sounds;
import 'info.dart';
import 'button.dart';

Future main() async {
  log('beginning...');
  await Hive.initFlutter();
  await Hive.openBox('localstorage');
  await dotenv.load(fileName: ".env");

  var box = Hive.box('localstorage');

  // creates collection storage
  if (box.get('collection') == null) {
    List<String> l = [];
    box.put('collection', l);
  }

  print("Hello there");
  // print(box.get('suggestedBirds').keys.toString());
  if (box.get('suggestedBirds') == null) {
    box.put('suggestedBirds', Map());
  }
  if (box.get('date') == null) {
    box.put('date', DateTime.now());
  }
  if (box.get('tmpBirds') == null) {
    box.put('tmpBirds', Map());
  }
  //Check to see if day has passed to update local storage
  if (box.get('date').day != DateTime.now().day) {
    box.put('date', DateTime.now());
    updateStoredBirds(box);
  }
  log('loaded stored birds');
  log('starting app...');
  runApp(const MyApp());
}

void updateStoredBirds(box) {
  var storedBirds = box.get('suggestedBirds');
  storedBirds.updateAll((key, value) => value + 1);
  storedBirds.removeWhere((key, value) => (value > 14) as bool);
  box.put('suggestedBirds', storedBirds);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eagle Eyes',
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
      home: const MyHomePage(title: 'Eagle Eyes'),
    );
  }
}

var themeNotifier = ValueNotifier<ThemeVariation>(
  const ThemeVariation(Colors.blue, Brightness.light),
);

class ThemeVariation {
  const ThemeVariation(this.color, this.brightness);
  final MaterialColor color;
  final Brightness brightness;
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
  void afterFirstLayout(BuildContext context) {
    // Calling the same function "after layout" to resolve the issue.
    Navigator.pop(context); // pop current page
    Navigator.pushNamed(context, "Setting");
    Navigator.popAndPushNamed(context, '/screenname');
  }

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

Future<Bird> fetchBirds(Future<LocationData> location) async {
  log('fetching bird data...');
  LocationData currLoc = await location;
  double? lat = currLoc.latitude;
  double? lng = currLoc.longitude;
  log("got location");
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

  log("it's ya boi");
  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    log("Hey there");
    List<Map<String, dynamic>> responseList =
        (jsonDecode(response.body) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

    List<Bird> jsonObjs =
        responseList.map((resp) => Bird.fromJson(resp)).toList();

    var rng = math.Random();
    late int selectedBird;

    Bird testBird = jsonObjs[0];

    var box = Hive.box('localstorage');

    var suggestedBirds = box.get('suggestedBirds');
    Map<String, int> blacklist = Map();

    box.put('tmpBirds', Map<String, int>.from(box.get('suggestedBirds')));
    log("time to test");
    while (!testBird.validBird) {
      selectedBird = rng.nextInt(jsonObjs.length);
      while (blacklist.keys.contains(selectedBird)) {
        selectedBird = rng.nextInt(jsonObjs.length);
      }
      testBird = await checkBird(jsonObjs[selectedBird], lat, lng, box);
      log(testBird.coords[0].toString());
      blacklist[testBird.spCode] = selectedBird;
      log("testing bird");
      log(selectedBird.toString());

      if (box.get('tmpBirds').isEmpty && box.get('suggestedBirds').isNotEmpty) {
        blacklist = Map();
      }
    }
    return testBird;
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    log(response.body);
    throw Exception('Failed to load album');
  }
}

Future<Bird> checkBird(Bird bird, double? lat, double? lng, box) async {
  var speciesCode = bird.spCode;
  final response = await http.get(
    Uri.parse(
        'https://api.ebird.org/v2/data/obs/geo/recent/$speciesCode?lat=$lat&lng=$lng'),
    headers: {
      'X-eBirdApiToken': dotenv.env['EBIRD_API_KEY'] ?? 'API_KEY not found',
    },
  );

  if (response.statusCode == 200) {
    Map<String, int> tmpBirds = box.get('tmpBirds');
    List<Map<String, dynamic>> responseList =
        (jsonDecode(response.body) as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

    var birdMarkers = [];
    responseList
        .forEach((map) => birdMarkers.add(LatLng(map['lat'], map['lng'])));

    log(birdMarkers.toString());
    bird.coords = List<LatLng>.from(birdMarkers);

    Map birdList = box.get('suggestedBirds');
    if (responseList.length < 10) {
      if (birdList.containsKey(speciesCode)) {
        tmpBirds.removeWhere((key, value) => key == speciesCode);
        box.put('tmpBirds', tmpBirds);
      }
      bird.validBird = false;
    } else {
      birdList[speciesCode] = 1;
      box.put('suggestedBirds', birdList);
      var numMarkers = math.min(responseList.length, 10);
      bird.validBird = true;
    }
    return bird;
  } else {
    log(response.body);
    throw Exception('Failed to look up species');
  }
}

class _MyHomePageState extends State<MyHomePage> {
  var box = Hive.box("localstorage");
  late GoogleMapController mapController;
  late AnimationController controller;
  // audio player variables
  late AudioPlayer player;
  late Stream<DurationState> durationState;
  final _isShowingWidgetOutline = false;
  final _labelLocation = TimeLabelLocation.below;
  final _labelType = TimeLabelType.totalTime;
  TextStyle? _labelStyle;
  final _thumbRadius = 10.0;
  final _labelPadding = 0.0;
  final _barHeight = 5.0;
  final _barCapShape = BarCapShape.round;
  Color? _baseBarColor;
  Color? _progressBarColor;
  Color? _bufferedBarColor;
  Color? _thumbColor;
  Color? _thumbGlowColor;
  final _thumbCanPaintOutsideBar = true;
  final birdPos = LatLng(37.416000, -122.077000);

  late Future<Bird> futureAlbum;
  late Future<String> description;
  late Future<LocationData> location;

  Set<Marker> markers = Set();

  String subtitle = "Bird of the Day";

  int _selectedIndex = 0;

  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        subtitle = 'Bird of the Day';
      } else {
        subtitle = 'Past Observations';
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) async {
    log('map initialized');
    final currentLocation = await location;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
            target:
                LatLng(currentLocation.latitude!, currentLocation.longitude!),
            zoom: 15),
      ),
    );
    controller.setMapStyle("[]");
  }

  void _setUpAudio(String name) async {
    final url = await sounds.fetchAudioURL(name);
    await player.setUrl(url);
  }

  @override
  void initState() {
    super.initState();
    // Hive.box('localstorage').clear();
    location = Location().getLocation();
    futureAlbum = fetchBirds(location);
    description = fetchBirdInfo(futureAlbum);
    player = AudioPlayer();
    durationState = Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
            player.positionStream,
            player.playbackEventStream,
            (position, playbackEvent) => DurationState(
                  progress: position,
                  buffered: playbackEvent.bufferedPosition,
                  total: playbackEvent.duration,
                ))
        .asBroadcastStream(); // warning: example does more than this, including setting the URL here.. this could cause issues later
  }

  // disposes audio player and resources when the app closes
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void onFoundButtonPressed() async {
    log("pressed found");
    var box = Hive.box('localstorage');
    List<String> collection = box.get('collection').cast<String>();
    Bird bird = await futureAlbum;
    LocationData loc = await location;
    DateTime now = DateTime.now();
    Observation obs =
        Observation(bird, now, LatLng(loc.latitude!, loc.longitude!));
    collection.add(jsonEncode(obs));
    box.put('collection', collection);
  }

  List<Widget> createCollection() {
    List<Widget> observations = <Widget>[];
    var box = Hive.box('localstorage');
    List collection = box.get('collection');
    for (String obsJson in collection) {
      Map<String, dynamic> obs = jsonDecode(obsJson);
      Observation o = Observation.fromJson(obs);
      observations.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Text(
                  o.bird.comName,
                  textScaleFactor: 1.5,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(' (${o.bird.sciName})',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
            Text(
                'Recorded on ${o.time.month} ${o.time.day}, ${o.time.year} at ${o.time.hour}:${o.time.minute}'),
            Text('Location: ${o.location.latitude},${o.location.longitude}'),
          ]),
        ),
      ));
    }
    return observations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title}: $subtitle'),
      ),
      body: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: (_selectedIndex == 0)
              ? KeepAlive(
                  keepAlive: true,
                  child: ListView(
                      padding: const EdgeInsets.all(12.0),
                      children: <Widget>[
                        // Bird Name
                        FutureBuilder<Bird>(
                          future: futureAlbum,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return BirdNameCard(bird: snapshot.data!);
                            } else if (snapshot.hasError) {
                              return Text('${snapshot.error}');
                            }
                            // By default, show a loading spinner.
                            return const LoadingIndicator();
                          },
                        ),

                        FutureBuilder<Bird>(
                          future: futureAlbum,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return BirdPhotoCarousel(bird: snapshot.data!);
                            } else if (snapshot.hasError) {
                              return Text('${snapshot.error}');
                            }
                            // By default, show a loading spinner.
                            return const LoadingIndicator();
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: FutureBuilder<Bird>(
                            future: futureAlbum,
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return ElevatedButton(
                                  onPressed: () {
                                    launch(
                                        'https://ebird.org/species/${snapshot.data!.spCode}');
                                  },
                                  child: const Text('More Information'),
                                );
                              } else if (snapshot.hasError) {
                                return Text('${snapshot.error}');
                              }
                              // By default, show a loading spinner.
                              return const LoadingIndicator();
                            },
                  markers.addAll([
                    Marker(
                      markerId: MarkerId('value0'),
                      position: snapshot.data!.coords[0],
                    Marker(
                    ),
                      markerId: MarkerId('value2'),
                      position: snapshot.data!.coords[1],
                    ),
                    Marker(
                      markerId: MarkerId('value3'),
                      position: snapshot.data!.coords[3],
                    Marker(
                    ),
                      markerId: MarkerId('value4'),
                      position: snapshot.data!.coords[3],
                    Marker(
                    ),
                      markerId: MarkerId('valu5'),
                      position: snapshot.data!.coords[4],
                    Marker(
                    ),
                      markerId: MarkerId('value6'),
                      position: snapshot.data!.coords[5],
                    ),
                    Marker(
                      position: snapshot.data!.coords[6],
                      markerId: MarkerId('value7'),
                    ),
                    Marker(
                      markerId: MarkerId('value8'),
                      position: snapshot.data!.coords[7],
                    ),
                      markerId: MarkerId('value9'),
                    Marker(
                      position: snapshot.data!.coords[9],
                    ),
                    Marker(
                      position: snapshot.data!.coords[9],
                      markerId: MarkerId('value10'),
                    )
                  ]);
                          ),
                        ),
                        // Bird Photo
                        // Birdcall Player
                        FutureBuilder<Bird>(
                          future: futureAlbum,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              _setUpAudio(snapshot.data!.sciName);
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Sample Call',
                                        textScaleFactor: 1.5,
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        decoration: _widgetBorder(),
                                        child: _progressBar(),
                                      ),
                                      _playButton(),
                                    ],
                                  ),
                                ),
                              );
                            } else if (snapshot.hasError) {
                              return Text('${snapshot.error}');
                            }
                            // By default, show a loading spinner.
                            return const LoadingIndicator();
                          },
                        ),
                        SizedBox(
                          height: 500,
                          child: Card(
                              child: GoogleMap(
                            onMapCreated: _onMapCreated,
                            padding: const EdgeInsets.all(8.0),
                            myLocationEnabled: true,
                            initialCameraPosition: const CameraPosition(
                                target: LatLng(0, 0), zoom: 3),
                          )),
                        ),
                        FutureBuilder<Bird>(
                            future: futureAlbum,
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return FoundButton(
                                  onPress: onFoundButtonPressed,
                                );
                              } else if (snapshot.hasError) {
                                return Text('${snapshot.error}');
                              }
                              // By default, show a loading spinner.
                              return const LoadingIndicator();
                            })
                      ]),
                )
              : ListView(
                  children: createCollection(),
                )),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Gallery',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        onTap: _onItemTapped,
      ),
    );
    setState(() {});
  }

  BoxDecoration _widgetBorder() {
    return BoxDecoration(
      border: _isShowingWidgetOutline
          ? Border.all(color: Colors.red)
          : Border.all(color: Colors.transparent),
    );
  }

  StreamBuilder<DurationState> _progressBar() {
    return StreamBuilder<DurationState>(
      stream: durationState,
      builder: (context, snapshot) {
        final durationState = snapshot.data;
        final progress = durationState?.progress ?? Duration.zero;
        final buffered = durationState?.buffered ?? Duration.zero;
        final total = durationState?.total ?? Duration.zero;
        return ProgressBar(
          progress: progress,
          buffered: buffered,
          total: total,
          onSeek: (duration) {
            player.seek(duration);
          },
          onDragUpdate: (details) {
            debugPrint('${details.timeStamp}, ${details.localPosition}');
          },
          barHeight: _barHeight,
          baseBarColor: _baseBarColor,
          progressBarColor: _progressBarColor,
          bufferedBarColor: _bufferedBarColor,
          thumbColor: _thumbColor,
          thumbGlowColor: _thumbGlowColor,
          barCapShape: _barCapShape,
          thumbRadius: _thumbRadius,
          thumbCanPaintOutsideBar: _thumbCanPaintOutsideBar,
          timeLabelLocation: _labelLocation,
          timeLabelType: _labelType,
          timeLabelTextStyle: _labelStyle,
          timeLabelPadding: _labelPadding,
        );
      },
    );
  }

  StreamBuilder<PlayerState> _playButton() {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;
        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          return Container(
            margin: const EdgeInsets.all(8.0),
            width: 50.0,
            height: 50.0,
            child: const LoadingIndicator(),
          );
        } else if (playing != true) {
          return IconButton(
            icon: const Icon(Icons.play_arrow),
            iconSize: 50.0,
            onPressed: player.play,
          );
        } else if (processingState != ProcessingState.completed) {
          return IconButton(
            icon: const Icon(Icons.pause),
            iconSize: 50.0,
            onPressed: player.pause,
          );
        } else {
          return IconButton(
            icon: const Icon(Icons.replay),
            iconSize: 50.0,
            onPressed: () => player.seek(Duration.zero),
          );
        }
      },
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
    imageLinks = fetchBirdPhotos(widget.bird, 5);
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
                options: CarouselOptions(
                    height: 400,
                    viewportFraction: 0.9,
                    enlargeCenterPage: false),
                items: links.map((link) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Image.network(
                        link,
                        fit: BoxFit.cover,
                      );
                    },
                  );
                }).toList(),
              );
            }));
  }
}

class DurationState {
  const DurationState({
    required this.progress,
    required this.buffered,
    this.total,
  });
  final Duration progress;
  final Duration buffered;
  final Duration? total;
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
        width: 50,
        height: 50,
        child: Center(child: CircularProgressIndicator()));
  }
}

class Observation {
  final Bird bird;
  final DateTime time;
  final LatLng location;
  const Observation(this.bird, this.time, this.location);

  factory Observation.fromJson(Map<String, dynamic> json) {
    return Observation(
        Bird.fromJson(json['bird']),
        DateTime.parse(json['time']),
        LatLng(json['latitude'], json['longitude']));
  }

  Map<String, dynamic> toJson() => {
        'bird': bird.toJson(),
        'time': time.toString(),
        'latitude': location.latitude,
        'longitude': location.longitude
      };
}
