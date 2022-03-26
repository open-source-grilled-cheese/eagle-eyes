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
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'bird.dart';
import 'photos.dart';
import 'sounds.dart' as sounds;
import 'info.dart';

Future main() async {
  await Hive.initFlutter();
  await Hive.openBox('localstorage');
  await dotenv.load(fileName: ".env");

  var box = Hive.box('localstorage');
  print("Hello there");
  print(box.get('suggestedBirds').keys.toString());
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

  runApp(const MyApp());
}

void updateStoredBirds(box) {
  Map<String, int> storedBirds = box.get('suggestedBirds');
  storedBirds.updateAll((key, value) => value + 1);
  storedBirds.removeWhere((key, value) => value > 14);
  box.put('suggestedBirds', storedBirds);
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

    var box = Hive.box('localstorage');

    box.put('tmpBirds', Map<String, int>.from(box.get('suggestedBirds')));
    List<int> blacklist = [];
    while (!validBird) {
      selectedBird = rng.nextInt(jsonObjs.length);
      while (blacklist.contains(selectedBird)) {
        selectedBird = rng.nextInt(jsonObjs.length);
      }
      validBird = await checkBird(jsonObjs[selectedBird], lat, lng, box);
      blacklist.add(selectedBird);
      log("testing bird");
      log(selectedBird.toString());

      if (box.get('tmpBirds').isEmpty && box.get('suggestedBirds').isNotEmpty) {
        blacklist = [];
      }
    }

    return jsonObjs[selectedBird];
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    print(response.body);
    throw Exception('Failed to load album');
  }
}

Future<bool> checkBird(Bird bird, double? lat, double? lng, box) async {
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

    Map birdList = box.get('suggestedBirds');
    if ((responseList.length < 10 || birdList.containsKey(speciesCode)) &&
        (tmpBirds.isNotEmpty || box.get('suggestedBirds').isEmpty)) {
      if (birdList.containsKey(speciesCode)) {
        tmpBirds.removeWhere((key, value) => key == speciesCode);
        box.put('tmpBirds', tmpBirds);
      }
      return false;
    } else {
      birdList[speciesCode] = 1;
      box.put('suggestedBirds', birdList);
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

  late Future<Bird> futureAlbum;
  late Future<String> description;

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

  void _setUpAudio(String name) async {
    final url = await sounds.fetchAudioURL(name);
    await player.setUrl(url);
  }

  @override
  void initState() {
    super.initState();

    futureAlbum = fetchBirds();
    description = fetchBirdInfo(futureAlbum);
    player = AudioPlayer();
    durationState = Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
        player.positionStream,
        player.playbackEventStream,
        (position, playbackEvent) => DurationState(
              progress: position,
              buffered: playbackEvent.bufferedPosition,
              total: playbackEvent.duration,
            )); // warning: example does more than this, including setting the URL here.. this could cause issues later
  }

  // disposes audio player and resources when the app closes
  @override
  void dispose() {
    player.dispose();
    super.dispose();
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
            FutureBuilder<Bird>(
              future: futureAlbum,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return BirdNameCard(bird: snapshot.data!);
                } else if (snapshot.hasError) {
                  return Text('${snapshot.error}');
                }
                // By default, show a loading spinner.
                return const CircularProgressIndicator();
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
                return const CircularProgressIndicator();
              },
            ),
            Card(
              child: FutureBuilder<String>(
                future: description,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(snapshot.data!);
                  } else if (snapshot.hasError) {
                    return Text('${snapshot.error}');
                  }
                  // By default, show a loading spinner.
                  return const CircularProgressIndicator();
                },
              ),
            ),
            // Bird Photo
            // Birdcall Player
            FutureBuilder<Bird>(
              future: futureAlbum,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  print('begin printing the audio card');
                  _setUpAudio(snapshot.data!.sciName);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            decoration: _widgetBorder(),
                            child: _progressBar(),
                          ),
                          _playButton(),
                        ],
                      ),
                    ),

                    // child: Row(children: [
                    //   IconButton(
                    //       onPressed: () => _playAudio(snapshot.data!.sciName),
                    //       iconSize: 64.0,
                    //       icon: const Icon(Icons.play_circle)),
                    // ]),
                  );
                } else if (snapshot.hasError) {
                  return Text('${snapshot.error}');
                }
                // By default, show a loading spinner.
                return const CircularProgressIndicator();
              },
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
            child: const CircularProgressIndicator(),
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
