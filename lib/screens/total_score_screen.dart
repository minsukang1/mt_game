import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/session_state.dart';

class TotalScoreScreen extends StatelessWidget {
  const TotalScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final totals = session.totals;
    final order = List.generate(session.teams.length, (i) => i)
      ..sort((a, b) => totals[b].compareTo(totals[a]));

    return Scaffold(
      appBar: AppBar(title: const Text('총점')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                for (var rank = 0; rank < order.length; rank++)
                  ListTile(
                    leading: CircleAvatar(child: Text('${rank + 1}')),
                    title: Text(session.teams[order[rank]].name),
                    subtitle: Text(session.teams[order[rank]].members.join(', ')),
                    trailing: Text(
                      '${totals[order[rank]]}점',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                const Divider(),
                for (final r in session.results)
                  ListTile(
                    dense: true,
                    title: Text(r.gameType),
                    subtitle: Text([
                      for (var i = 0; i < r.scores.length; i++)
                        '${session.teams[i].name} ${r.scores[i]}'
                    ].join(' / ')),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('메인으로'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}