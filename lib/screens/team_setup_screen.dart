import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/session_state.dart';
import '../models/team.dart';
import 'game_select_screen.dart';

class TeamSetupScreen extends StatefulWidget {
  const TeamSetupScreen({super.key});

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen> {
  int teamCount = 2;
  final List<TextEditingController> nameCtrls = [];
  final List<TextEditingController> memberCtrls = [];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  void _syncControllers() {
    while (nameCtrls.length < teamCount) {
      nameCtrls.add(TextEditingController(text: '${nameCtrls.length + 1}팀'));
      memberCtrls.add(TextEditingController());
    }
    while (nameCtrls.length > teamCount) {
      nameCtrls.removeLast().dispose();
      memberCtrls.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final c in [...nameCtrls, ...memberCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    final teams = List.generate(teamCount, (i) {
      final name = nameCtrls[i].text.trim();
      return Team(
        name: name.isEmpty ? '${i + 1}팀' : name,
        members: memberCtrls[i].text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
    });
    context.read<SessionState>().startSession(teams);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GameSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('팀 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('팀 수'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 2, label: Text('2팀')),
              ButtonSegment(value: 3, label: Text('3팀')),
              ButtonSegment(value: 4, label: Text('4팀')),
            ],
            selected: {teamCount},
            onSelectionChanged: (s) => setState(() {
              teamCount = s.first;
              _syncControllers();
            }),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < teamCount; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: nameCtrls[i],
                      decoration: const InputDecoration(labelText: '팀 이름'),
                    ),
                    TextField(
                      controller: memberCtrls[i],
                      decoration: const InputDecoration(
                        labelText: '팀원 (쉼표로 구분)',
                        hintText: '철수, 영희, 민수',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _start, child: const Text('다음')),
        ],
      ),
    );
  }
}