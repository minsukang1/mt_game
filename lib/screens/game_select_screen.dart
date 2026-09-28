import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/session_state.dart';
import 'games/placeholder_game_screen.dart';
import 'total_score_screen.dart';

const gameNames = ['상식퀴즈', '줄줄이 말해요', '고요 속의 외침', '인물 퀴즈'];

class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final totals = session.totals;

    return Scaffold(
      appBar: AppBar(title: const Text('게임 선택')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              children: [
                for (var i = 0; i < session.teams.length; i++)
                  Chip(label: Text('${session.teams[i].name} ${totals[i]}점')),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                for (final name in gameNames)
                  ListTile(
                    title: Text(name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaceholderGameScreen(gameName: name),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TotalScoreScreen()),
                ),
                child: const Text('게임 종료 · 총점 보기'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}