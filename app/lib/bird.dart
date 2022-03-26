class Bird {
  final String comName;
  final String sciName;
  final String obsDt;

  const Bird({
    required this.comName,
    required this.sciName,
    required this.obsDt,
  });

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      comName: json['comName'],
      sciName: json['sciName'],
      obsDt: json['obsDt'],
    );
  }
}
