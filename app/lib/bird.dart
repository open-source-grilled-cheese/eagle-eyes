import 'package:google_maps_flutter/google_maps_flutter.dart';

class Bird {
  final String spCode;
  final String comName;
  final String sciName;
  final String obsDt;
  final int? howMany;
  final double lat;
  final double lng;
  bool validBird;
  List<LatLng> coords;

  Bird(
      {required this.spCode,
      required this.comName,
      required this.sciName,
      required this.obsDt,
      required this.lat,
      required this.lng,
      required this.howMany,
      required this.validBird,
      required this.coords});

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
        spCode: json['speciesCode'],
        comName: json['comName'],
        sciName: json['sciName'],
        obsDt: json['obsDt'],
        lat: json['lat'],
        lng: json['lng'],
        howMany: json['howMany'],
        coords: [],
        validBird: false);
  }

  Map<String, dynamic> toJson() => {
        'speciesCode': spCode,
        'comName': comName,
        'sciName': sciName,
        'obsDt': obsDt,
        'howMany': howMany
      };
}
