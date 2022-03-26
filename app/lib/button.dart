import 'dart:math';
//flutter run --no-sound-null-safety
//because I can't figure out the migration tool
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
void main() => runApp(const ConfettiSample());
  
class ConfettiSample extends StatelessWidget {
  const ConfettiSample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Confetti',
        home: Scaffold(
          backgroundColor: Colors.grey[900],
          body: MyApp(),
        ));
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
              child: const Text('Found it!'),
              style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                  //textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 30)),
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.teal),
              ),
              
              onPressed: () => {
                  _controller.play(),
              },
            ),      
          
          //confetti widget
          Align(
            alignment: Alignment.bottomCenter,
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: 3*pi/2,
              emissionFrequency: 0.01,
              minimumSize: const Size(10, 10), // set the minimum potential size for the confetti (width, height)
              maximumSize: const Size(50, 50), // set the maximum potential size for the confetti (width, height)
              maxBlastForce: 40,
              minBlastForce: 20,
              numberOfParticles: 40,
               colors: const [
                Colors.teal,
                Colors.pink,
                Colors.yellow,
                Colors.green,
                Colors.purple,
              ], // manually specify the colors to be used
              gravity: 0.3,
            ),
          ),
         
        ],
      ),
    ),);
  }

}