
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/session_state.dart';
import '../../models/game_result.dart';
import '../../models/team.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

const int lineGameSeconds = 30;

class LineQuestion {
  final String prompt;
  final String answer;

  const LineQuestion({
    required this.prompt,
    required this.answer,
  });
}

Map<String, List<LineQuestion>> lineQuestions = {};

bool isLoadingQuestions = true;
String? questionLoadError;

enum LineGamePhase {
  setup,
  ready,
  playing,
  finished,
}

class LineGameScreen extends StatefulWidget {
  const LineGameScreen({super.key});

  @override
  State<LineGameScreen> createState() => _LineGameScreenState();
}

class _LineGameScreenState extends State<LineGameScreen> {
  final Set<String> selectedCategories = {'사자성어'};

  final List<String> categories = [
    '사자성어',
    '일상 단어',
    '속담',
  ];
  int maxQuestionsPerTeam = 10;
  // 팀별로 사용할 문제 목록
  List<List<LineQuestion>> teamQuestionSets = [];
  LineGamePhase phase = LineGamePhase.setup;

  late List<int> scores;
  List<LineQuestion> questions = [];

  int teamIdx = 0;
  int questionIdx = 0;
  int remaining = lineGameSeconds;

  bool answerRevealed = false;
  bool saved = false;

  Timer? timer;

  Future<void> _loadLineQuestions() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/questions/line_game.json',
      );

      final List<dynamic> decoded = jsonDecode(jsonString);

      final Map<String, List<LineQuestion>> loadedQuestions = {};

      for (final item in decoded) {
        final category = item['category']?.toString().trim() ?? '';
        final prompt = item['prompt']?.toString().trim() ?? '';
        final answer = item['answer']?.toString().trim() ?? '';

        if (category.isEmpty || prompt.isEmpty || answer.isEmpty) {
          continue;
        }

        loadedQuestions.putIfAbsent(category, () => []);

        loadedQuestions[category]!.add(
          LineQuestion(
            prompt: prompt,
            answer: answer,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        lineQuestions = loadedQuestions;
        isLoadingQuestions = false;
        questionLoadError = null;
      });

      debugPrint('[줄줄이 말해요] JSON 로딩 성공');
      debugPrint('[줄줄이 말해요] 카테고리: ${lineQuestions.keys.toList()}');

      for (final entry in lineQuestions.entries) {
        debugPrint(
          '[줄줄이 말해요] ${entry.key}: ${entry.value.length}문제',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[줄줄이 말해요] JSON 로딩 실패: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        isLoadingQuestions = false;
        questionLoadError = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final teams = context.read<SessionState>().teams;
    scores = List<int>.filled(teams.length, 0);
    _loadLineQuestions();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  LineQuestion get currentQuestion => questions[questionIdx];
  void _showStartError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  void _startGame() {
    if (selectedCategories.isEmpty) {
      _showStartError('카테고리를 하나 이상 선택해주세요.');
      return;
    }

    final teams = context.read<SessionState>().teams;

    if (teams.isEmpty) {
      _showStartError('등록된 팀이 없습니다.');
      return;
    }

    final pool = selectedCategories
        .expand((category) => lineQuestions[category] ?? <LineQuestion>[])
        .toList();

    // 같은 문제가 JSON에 중복 등록된 경우도 제거
    final uniquePool = <String, LineQuestion>{};

    for (final question in pool) {
      final key = '${question.prompt}|${question.answer}';
      uniquePool[key] = question;
    }

    final availableQuestions = uniquePool.values.toList();

    if (availableQuestions.isEmpty) {
      _showStartError('선택한 카테고리에 문제가 없습니다.');
      return;
    }

    // 팀별 문제 목록을 따로 생성한다.
    // 한 팀의 목록 안에서는 문제가 중복되지 않는다.
    // 전체 문제를 한 번 섞고, 한 번만 배정한다.
    // 이미 배정된 문제는 다른 팀에 배정하지 않는다.
    final shuffledQuestions = List<LineQuestion>.from(availableQuestions)
      ..shuffle();

    final newTeamQuestionSets = <List<LineQuestion>>[];
    final requiredTotal = teams.length * maxQuestionsPerTeam;

    // 팀 수 × 팀당 문제 수만큼 고유한 문제가 없으면 시작하지 않는다.
    if (shuffledQuestions.length < requiredTotal) {
      _showStartError(
        '중복 없이 진행하려면 문제가 최소 $requiredTotal개 필요합니다. '
        '현재 선택한 카테고리의 고유 문제는 ${shuffledQuestions.length}개입니다. '
        '카테고리를 더 선택하거나 팀당 문제 수를 줄여주세요.',
      );
      return;
    }

    var startIndex = 0;

    for (var i = 0; i < teams.length; i++) {
      final endIndex = startIndex + maxQuestionsPerTeam;

      newTeamQuestionSets.add(
        shuffledQuestions.sublist(startIndex, endIndex),
      );

      startIndex = endIndex;
    }

    setState(() {
      teamQuestionSets = newTeamQuestionSets;

      questions
        ..clear()
        ..addAll(teamQuestionSets.first);

      questionIdx = 0;
      teamIdx = 0;
      scores = List<int>.filled(teams.length, 0);
      remaining = lineGameSeconds;
      answerRevealed = false;
      saved = false;
      phase = LineGamePhase.ready;
    });
  }

  void _startTeam() {
    setState(() {
      phase = LineGamePhase.playing;
      remaining = lineGameSeconds;
      answerRevealed = false;
    });

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (remaining <= 1) {
        t.cancel();
        _finishTeam();
      } else {
        setState(() => remaining--);
      }
    });
  }

  void _finishTeam() {
    timer?.cancel();
    if (!mounted) return;

    final teams = context.read<SessionState>().teams;

    setState(() {
      remaining = 0;
      answerRevealed = false;

      if (teamIdx + 1 < teams.length) {
        teamIdx++;

        // 다음 팀 전용 문제 목록으로 교체
        questions
          ..clear()
          ..addAll(teamQuestionSets[teamIdx]);

        questionIdx = 0;
        phase = LineGamePhase.ready;
      } else {
        phase = LineGamePhase.finished;
      }
    });
  }

  void _nextQuestion({required bool correct}) {
    if (phase != LineGamePhase.playing) return;

    if (correct) {
      setState(() {
        scores[teamIdx]++;
      });
    }

    // 마지막 문제를 처리했으면 다음 팀으로 자동 이동
    if (questionIdx + 1 >= questions.length) {
      _finishTeam();
      return;
    }

    setState(() {
      questionIdx++;
      answerRevealed = false;
    });
  }

  void _saveAndExit() {
    timer?.cancel();

    if (!saved && phase != LineGamePhase.setup) {
      context.read<SessionState>().addResult(
            GameResult(
              gameType: '줄줄이 말해요 - ${selectedCategories.join(', ')}',
              scores: List<int>.of(scores),
            ),
          );
      saved = true;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final teams = session.teams;

    return Scaffold(
      appBar: AppBar(
        title: const Text('줄줄이 말해요'),
        actions: [
          if (phase != LineGamePhase.setup)
            TextButton(
              onPressed: _saveAndExit,
              child: const Text('저장하고 종료'),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (phase) {
          LineGamePhase.setup => _buildSetup(teams),
          LineGamePhase.ready => _buildReady(teams),
          LineGamePhase.playing => _buildPlaying(teams),
          LineGamePhase.finished => _buildFinished(teams),
        },
      ),
    );
  }

  Widget _buildSetup(List<Team> teams) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '카테고리 선택',
          style: Theme.of(context).textTheme.headlineSmall,
        ),

        const SizedBox(height: 24),
        Text(
          '팀당 최대 문제 수',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [5, 10, 15, 20].map((count) {
            return ChoiceChip(
              label: Text('$count문제'),
              selected: maxQuestionsPerTeam == count,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    maxQuestionsPerTeam = count;
                  });
                }
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 8),
        const Text('선택한 카테고리의 문제로 팀별 30초 동안 진행합니다.'),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = selectedCategories.contains(category);

            return FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedCategories.add(category);
                  } else {
                    selectedCategories.remove(category);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text(
          '참여 팀',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (teams.isEmpty)
          const Text('등록된 팀이 없습니다. 먼저 팀을 등록해 주세요.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final team in teams) Chip(label: Text(team.name)),
            ],
          ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '게임 방법',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('1. 화면에 나온 앞부분을 보고 뒷부분을 말합니다.'),
                Text('2. 정답이면 정답 버튼을 눌러 1점을 획득합니다.'),
                Text('3. 모르거나 틀리면 넘기기를 누릅니다.'),
                Text('4. 팀별 30초가 끝나면 다음 팀 차례로 넘어갑니다.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoadingQuestions ? null : _startGame,
            child: Text(
              isLoadingQuestions
                  ? '문제 불러오는 중...'
                  : '게임 시작',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReady(List<Team> teams) {
    final team = teams[teamIdx];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCategories.join(', '),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              team.name,
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('현재 점수: ${scores[teamIdx]}점'),
            const SizedBox(height: 8),
            const Text('준비되면 시작 버튼을 누르세요. 제한 시간은 30초입니다.'),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: FilledButton.icon(
                onPressed: _startTeam,
                icon: const Icon(Icons.play_arrow),
                label: const Text('팀 차례 시작'),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPlaying(List<Team> teams) {
    final team = teams[teamIdx];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            constraints.maxWidth > constraints.maxHeight;

        final compact = isLandscape || constraints.maxHeight < 500;
        final padding = compact ? 8.0 : 16.0;
        final gap = compact ? 6.0 : 12.0;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              // 팀 이름과 남은 시간
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${team.name} 차례 · ${scores[teamIdx]}점',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '$remaining초',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: remaining <= 10
                              ? Theme.of(context).colorScheme.error
                              : null,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),

              SizedBox(height: gap),

              LinearProgressIndicator(
                value: remaining / lineGameSeconds,
                minHeight: 5,
              ),

              SizedBox(height: gap),

              // 남은 화면 공간을 문제 카드가 사용
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 8 : 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            selectedCategories.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),

                          SizedBox(height: compact ? 4 : 12),

                          const Text('앞부분'),

                          SizedBox(height: compact ? 4 : 8),

                          Expanded(
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  currentQuestion.prompt,
                                  style: (compact
                                          ? Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                          : Theme.of(context)
                                              .textTheme
                                              .displayMedium)
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),

                          if (answerRevealed) ...[
                            SizedBox(height: compact ? 2 : 8),
                            const Text('정답'),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  currentQuestion.answer,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ] else
                            OutlinedButton(
                              onPressed: () {
                                setState(() => answerRevealed = true);
                              },
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 12 : 20,
                                  vertical: compact ? 4 : 8,
                                ),
                              ),
                              child: const Text('정답 확인'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: gap),

              // 하단 버튼은 화면 너비에 맞춰 배치
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: compact ? 42 : 52,
                      child: FilledButton.icon(
                        onPressed: () => _nextQuestion(correct: true),
                        icon: const Icon(Icons.check),
                        label: const Text('정답 +1점'),
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: SizedBox(
                      height: compact ? 42 : 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _nextQuestion(correct: false),
                        icon: const Icon(Icons.skip_next),
                        label: const Text('넘기기'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildFinished(List<Team> teams) {
    final ranked = List<int>.generate(teams.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 64),
          const SizedBox(height: 12),
          Text(
            '게임 종료!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                for (var rank = 0; rank < ranked.length; rank++)
                    Card(
                        child: ListTile(
                        leading: CircleAvatar(
                            child: Text('${rank + 1}'),
                        ),
                        title: Text(teams[ranked[rank]].name),
                        trailing: Text(
                            '${scores[ranked[rank]]}점',
                            style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ),
                    ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saveAndExit,
              child: const Text('점수 저장하고 게임 선택으로'),
            ),
          ),
        ],
      ),
    );
  }
}
