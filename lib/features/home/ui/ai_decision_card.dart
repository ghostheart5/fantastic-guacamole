import 'package:fantastic_guacamole/core/services/si_engine_service.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:flutter/material.dart';

class AiDecisionCard extends StatefulWidget {
  const AiDecisionCard({super.key, required this.siEngine});

  final SIEngineService siEngine;

  @override
  State<AiDecisionCard> createState() => _AiDecisionCardState();
}

class _AiDecisionCardState extends State<AiDecisionCard> {
  SiDecisionEntity? _decision;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final SiDecisionEntity decision =
        await widget.siEngine.think('what should user do next?');
    if (mounted) {
      setState(() {
        _decision = decision;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final SiDecisionEntity d = _decision!;
    final String message =
        d.action.isNotEmpty ? d.action : d.rationale;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'What to do next',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(message),
            if (d.shouldTakeBreak)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Consider a short break.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
