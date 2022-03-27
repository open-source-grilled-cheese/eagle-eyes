class Bird {
  final String spCode;
  final String comName;
  final String sciName;
  final String obsDt;
  final int? howMany;

  const Bird({
    required this.spCode,
    required this.comName,
    required this.sciName,
    required this.obsDt,
    required this.howMany,
  });

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      spCode: json['speciesCode'],
      comName: json['comName'],
      sciName: json['sciName'],
      obsDt: json['obsDt'],
      howMany: json['howMany'],
    );
  }

  Map<String, dynamic> toJson() => {
        'speciesCode': spCode,
        'comName': comName,
        'sciName': sciName,
        'obsDt': obsDt,
        'howMany': howMany
      };
}
