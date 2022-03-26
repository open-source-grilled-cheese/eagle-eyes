class Bird {
  final String comName;
  final String sciName;
  final String obsDt;
  final String speciesCode;

  const Bird({
    required this.comName,
    required this.sciName,
    required this.obsDt,
    required this.speciesCode,
  });

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      comName: json['comName'],
      sciName: json['sciName'],
      obsDt: json['obsDt'],
      speciesCode: json['speciesCode'],
    );
  }
}
