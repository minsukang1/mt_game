import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/question_loader.dart';
import '../../data/session_state.dart';
import '../../models/game_result.dart';
import '../../models/quiz_question.dart';

const quizSeconds = 5;

enum Phase { setup, ready, playing, finished }

class QuizGameScreen extends StatefulWidget {
  const QuizGameScreen({super.key});

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  List<QuizQuestion> all = [];
  List<String> categories = [];
  final Set<String> selected = {};
  int perTeam = 5;

  Phase phase = Phase.setup;
  bool loaded = false;

  late List<int> scores;
  List<List<QuizQuestion>> assigned = []; // 팀별로 배정된 문제 (서로 겹치지 않음)
  int teamIdx = 0;
  int qIdx = 0;
  int remaining = quizSeconds;
  bool revealed = false;
  Timer? timer;

  int get teamCount => context.read<SessionState>().teams.length;

  List<QuizQuestion> get pool =>
      all.where((q) => selected.contains(q.category)).toList();

  @override
  void initState() {
    super.initState();
    scores = List.filled(context.read<SessionState>().teams.length, 0);
    _load();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await loadQuiz();
    if (!mounted) return;
    setState(() {
      all = data;
      categories = data.map((q) => q.category).toSet().toList();
      selected.addAll(categories);
      loaded = true;
    });
  }

  // 선택한 문제를 섞은 뒤 팀마다 다른 구간을 잘라서 배정
  void _start() {
    final p = pool;
    p.shuffle();
    final n = perTeam.clamp(1, p.length ~/ teamCount).toInt();
    assigned = List.generate(teamCount, (t) => p.sublist(t * n, (t + 1) * n));
    scores = List.filled(teamCount, 0);
    teamIdx = 0;
    qIdx = 0;
    setState(() => phase = Phase.ready);
  }

  void _beginTeam() {
    setState(() {
      phase = Phase.playing;
      qIdx = 0;
      revealed = false;
    });
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    setState(() => remaining = quizSeconds);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remaining <= 1) {
        t.cancel();
        setState(() => remaining = 0);
        return;
      }
      setState(() => remaining--);
    });
  }

  void _answer({required bool correct}) {
    if (correct) scores[teamIdx]++;
    timer?.cancel();
    if (qIdx + 1 < assigned[teamIdx].length) {
      setState(() {
        qIdx++;
        revealed = false;
      });
      _startTimer();
    } else if (teamIdx + 1 < teamCount) {
      setState(() {
        teamIdx++;
        qIdx = 0;
        revealed = false;
        phase = Phase.ready;
      });
    } else {
      setState(() => phase = Phase.finished);
    }
  }

  void _save() {
    timer?.cancel();
    context.read<SessionState>().addResult(
          GameResult(gameType: '상식퀴즈', scores: List.of(scores)),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final teams = context.read<SessionState>().teams;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상식퀴즈'),
        actions: [
          if (phase != Phase.setup)
            TextButton(onPressed: _save, child: const Text('저장하고 종료')),
        ],
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 모든 팀의 게임이 끝났을 때만 점수 공개
                if (phase == Phase.finished)
                Padding(
                    padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                    ),
                    child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                        for (var i = 0; i < teams.length; i++)
                        Chip(
                            label: Text(
                            '${teams[i].name} ${scores[i]}점',
                            ),
                        ),
                    ],
                    ),
                ),
                Expanded(child: _body(teams)),
                Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                    ),
                    child: SizedBox(
                        width: double.infinity,
                        child: _bottom(),
                    ),
                ),
              ],
            ),
    );
  }

  Widget _body(List teams) {
    switch (phase) {
      case Phase.setup:
        return _setupView();
      case Phase.ready:
        return _readyView(teams);
      case Phase.playing:
        return _questionView(teams);
      case Phase.finished:
        return const Center(child: Text('모든 팀이 끝났어요'));
    }
  }

  Widget _setupView() {
    final theme = Theme.of(context);
    final p = pool;
    final maxN = p.length ~/ teamCount;
    final n = maxN < 1 ? 0 : perTeam.clamp(1, maxN).toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('카테고리', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final c in categories)
              FilterChip(
                label: Text(
                    '$c (${all.where((q) => q.category == c).length})'),
                selected: selected.contains(c),
                onSelected: (v) => setState(() {
                  v ? selected.add(c) : selected.remove(c);
                }),
              ),
          ],
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => selected.addAll(categories)),
              child: const Text('전체 선택'),
            ),
            TextButton(
              onPressed: () => setState(selected.clear),
              child: const Text('전체 해제'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('팀당 문제 수', style: theme.textTheme.titleMedium),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: n > 1 ? () => setState(() => perTeam = n - 1) : null,
            ),
            Text('$n', style: theme.textTheme.headlineMedium),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed:
                  n < maxN ? () => setState(() => perTeam = n + 1) : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '선택한 문제 ${p.length}개 · $teamCount팀 → 팀당 최대 $maxN문제\n'
          '팀마다 서로 다른 문제가 나와요.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _readyView(List teams) {
    final theme = Theme.of(context);
    final t = teams[teamIdx];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${t.name} 차례', style: theme.textTheme.displaySmall),
          const SizedBox(height: 12),
          if (t.members.isNotEmpty) Text(t.members.join(', ')),
          const SizedBox(height: 12),
          Text('${assigned[teamIdx].length}문제 · 문제당 $quizSeconds초'),
        ],
      ),
    );
  }

Widget _questionView(List teams) {
  final q = assigned[teamIdx][qIdx];
  final theme = Theme.of(context);

  return LayoutBuilder(
    builder: (context, constraints) {
      // 현재 문제 영역의 실제 너비와 높이
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;

      // 화면이 작으면 글자도 작아지고,
      // 화면이 크면 글자도 커지도록 설정
      final questionFontSize =
          (height * 0.10).clamp(18.0, 40.0);
      final timerFontSize =
          (height * 0.16).clamp(30.0, 60.0);
      final answerFontSize =
          (height * 0.075).clamp(18.0, 32.0);

      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: height > 0 ? height - 8 : 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 현재 팀과 문제 번호
                Text(
                  '${teams[teamIdx].name} · '
                  '문제 ${qIdx + 1}/${assigned[teamIdx].length} · '
                  '${q.category}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: width < 400 ? 14 : 18,
                  ),
                ),

                const SizedBox(height: 4),

                // 남은 시간
                Text(
                  '$remaining',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: timerFontSize,
                    color: remaining <= 5
                        ? Colors.red
                        : null,
                  ),
                ),

                if (remaining == 0)
                  Text(
                    '시간 종료!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.red,
                    ),
                  ),

                const SizedBox(height: 8),

                // 문제 본문
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    q.question,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: questionFontSize,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),

                // 정답 보기 버튼을 누른 뒤에만 정답 표시
                if (revealed) ...[
                  const SizedBox(height: 12),
                  Text(
                    q.answer,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: answerFontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _bottom() {
    switch (phase) {
      case Phase.setup:
        final maxN = pool.length ~/ teamCount;
        return FilledButton(
          onPressed: maxN >= 1 ? _start : null,
          child: const Text('시작'),
        );
      case Phase.ready:
        return FilledButton(
          onPressed: _beginTeam,
          child: const Text('문제 시작'),
        );
      case Phase.playing:
        if (!revealed) {
          return FilledButton(
            onPressed: () => setState(() => revealed = true),
            child: const Text('정답 보기'),
          );
        }
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _answer(correct: false),
                child: const Text('틀림'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => _answer(correct: true),
                child: const Text('맞음'),
              ),
            ),
          ],
        );
      case Phase.finished:
        return FilledButton(onPressed: _save, child: const Text('점수 저장'));
    }
  }
}