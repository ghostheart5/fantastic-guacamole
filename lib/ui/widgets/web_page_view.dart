import 'package:flutter/material.dart';

class WebPageView extends StatelessWidget {
  const WebPageView({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(body),
            ],
          ),
        ),
      ),
    );
  }
}
