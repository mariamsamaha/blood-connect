import 'package:flutter/material.dart';

class AiCheckScreen extends StatelessWidget {
  const AiCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Health Check')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'AI eligibility check coming soon.\n\nFor now, ensure you are feeling well, hydrated, and meet the basic donor criteria before heading to the hospital.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
