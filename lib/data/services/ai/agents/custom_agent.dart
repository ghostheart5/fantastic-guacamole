import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';

class CustomAgent extends AiAgent {
  const CustomAgent({this.identifier = 'custom'});

  final String identifier;

  @override
  String get name => identifier;

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    return <String, dynamic>{
      'agent': name,
      'mode': 'custom',
      'request': request,
      'status': 'ready',
    };
  }
}
