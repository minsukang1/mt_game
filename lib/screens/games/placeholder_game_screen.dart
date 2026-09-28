import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/session_state.dart';
import '../../models/game_result.dart';

class PlaceholderGameScreen extends StatefulWidget {
  final String gameName;
  const PlaceholderGameScreen({super.key, required this.gameName});

  @override
  State<PlaceholderGameScreen> createState() => _PlaceholderGameScreenState();
}

class _PlaceholderGameScreenState extends State<PlaceholderGameScreen> {
  late List<int> scores;

  @override
  void initState() {
    super.initState();
    scores = List.filled(context.read<SessionState>().teams.length, 0);
  }

  void _save() {
    context.read<SessionState>().addResult(
          GameResult(gameType: widget.gameName, scores: List.of(scores)),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final teams = context.read<SessionState>().teams;

    return Scaffold(
      appBar: AppBar(title: Text(widget.gameName)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < teams.length; i++)
                  ListTile(
                    title: Text(teams[i].name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => setState(() => scores[i]--),
                        ),
                        Text('${scores[i]}',
                            style: Theme.of(context).textTheme.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => scores[i]++),
                        ),
                      ],
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
                onPressed: _save,
                child: const Text('점수 저장'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}