import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
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

  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
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
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
