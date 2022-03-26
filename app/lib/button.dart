import 'dart:math';
//flutter run --no-sound-null-safety
//because I can't figure out the migration tool
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class FoundButton extends StatefulWidget {
  const FoundButton({Key? key}) : super(key: key);
  @override
  _FoundButtonState createState() => _FoundButtonState();
}

class _FoundButtonState extends State<FoundButton> {
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: 100,
            width: 250,
            child: TextButton(
              child: const Text(
                'Found it!',
                textScaleFactor: 3.0,
              ),
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                //textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 30)),
                backgroundColor: MaterialStateProperty.all<Color>(Colors.teal),
              ),
              onPressed: () => {
                if (_controller.state == ConfettiControllerState.stopped)
                  _controller.play(),
              },
            ),
          ),
        ),

        //confetti widget
        Align(
          alignment: Alignment.bottomCenter,
          child: ConfettiWidget(
            blastDirectionality: BlastDirectionality.explosive,
            confettiController: _controller,
            emissionFrequency: 0.01,
            minimumSize: const Size(10,
                10), // set the minimum potential size for the confetti (width, height)
            maximumSize: const Size(50,
                50), // set the maximum potential size for the confetti (width, height)
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
            gravity: 0.1,
          ),
        ),
      ],
    );
  }
}
