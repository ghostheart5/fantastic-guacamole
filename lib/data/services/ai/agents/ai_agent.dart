abstract class AiAgent {
  const AiAgent();

  String get name;

  Future<Map<String, dynamic>> execute(Map<String, dynamic> request);
}
