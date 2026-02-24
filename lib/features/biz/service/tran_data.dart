class TranData {
  final String siq;
  final String outDs;
  final Map<String, dynamic>? params;

  TranData({
    required this.siq,
    required this.outDs,
    this.params,
  });

  Map<String, dynamic> toJson() {
    return {
      "_siq": siq,
      "outDs": outDs,
      ...?params,
    };
  }
}