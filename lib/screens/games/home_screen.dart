import 'package:flutter/material.dart';
import 'team_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MT 게임', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamSetupScreen()),
              ),
              child: const Text('새 게임 시작'),
            ),
          ],
        ),
      ),
    );
  }
}