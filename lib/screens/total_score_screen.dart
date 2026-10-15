import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/session_state.dart';

class TotalScoreScreen extends StatelessWidget {
  const TotalScoreScreen({super.key});

  Future<void> _confirmGoHome(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게임 종료'),
        content: const Text(
          '메인 화면으로 돌아가시겠습니까?\n현재 진행 중인 게임은 종료됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('메인으로 가기'),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final totals = session.totals;

    final order = List.generate(session.teams.length, (i) => i)
      ..sort((a, b) => totals[b].compareTo(totals[a]));

    return Scaffold(
      appBar: AppBar(
        title: const Text('총점'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    '팀별 최종 점수',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                for (var rank = 0; rank < order.length; rank++)
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${rank + 1}'),
                      ),
                      title: Text(
                        session.teams[order[rank]].name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          session.teams[order[rank]].members.isEmpty
                              ? '등록된 참가자 없음'
                              : '참가자: ${session.teams[order[rank]].members.join(', ')}',
                        ),
                      ),
                      trailing: Text(
                        '${totals[order[rank]]}점',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),

                const Divider(height: 32),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '게임별 점수',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                for (final r in session.results)
                  ListTile(
                    dense: true,
                    title: Text(r.gameType),
                    subtitle: Text([
                      for (var i = 0; i < r.scores.length; i++)
                        '${session.teams[i].name} ${r.scores[i]}점',
                    ].join(' / ')),
                  ),
              ],
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _confirmGoHome(context),
                  child: const Text('메인으로 가기'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}