abstract class AiTool {
  const AiTool();

  String get name;

  Future<Map<String, dynamic>> run(Map<String, dynamic> input);
}
