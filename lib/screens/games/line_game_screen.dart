
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/session_state.dart';
import '../../models/game_result.dart';
import '../../models/team.dart';

const int lineGameSeconds = 30;

class LineQuestion {
  final String prompt;
  final String answer;

  const LineQuestion({
    required this.prompt,
    required this.answer,
  });
}

const Map<String, List<LineQuestion>> lineQuestions = {
  '사자성어': [
    LineQuestion(prompt: '고진', answer: '감래'),
    LineQuestion(prompt: '새옹', answer: '지마'),
    LineQuestion(prompt: '일석', answer: '이조'),
    LineQuestion(prompt: '동문', answer: '서답'),
    LineQuestion(prompt: '우왕', answer: '좌왕'),
    LineQuestion(prompt: '작심', answer: '삼일'),
    LineQuestion(prompt: '전화', answer: '위복'),
    LineQuestion(prompt: '과유', answer: '불급'),
    LineQuestion(prompt: '자업', answer: '자득'),
    LineQuestion(prompt: '금상', answer: '첨화'),
    LineQuestion(prompt: '설상', answer: '가상'),
    LineQuestion(prompt: '역지', answer: '사지'),
    LineQuestion(prompt: '이심', answer: '전심'),
    LineQuestion(prompt: '청출', answer: '어람'),
    LineQuestion(prompt: '대기', answer: '만성'),
    LineQuestion(prompt: '다다', answer: '익선'),
    LineQuestion(prompt: '유비', answer: '무환'),
    LineQuestion(prompt: '오리', answer: '무중'),
    LineQuestion(prompt: '백전', answer: '백승'),
    LineQuestion(prompt: '천생', answer: '연분'),
  ],
  '일상 단어': [
    LineQuestion(prompt: '휴대', answer: '전화'),
    LineQuestion(prompt: '대한', answer: '민국'),
    LineQuestion(prompt: '비밀', answer: '번호'),
    LineQuestion(prompt: '손목', answer: '시계'),
    LineQuestion(prompt: '교통', answer: '카드'),
    LineQuestion(prompt: '고속', answer: '도로'),
    LineQuestion(prompt: '김치', answer: '찌개'),
    LineQuestion(prompt: '감자', answer: '튀김'),
    LineQuestion(prompt: '생일', answer: '파티'),
    LineQuestion(prompt: '택배', answer: '상자'),
    LineQuestion(prompt: '종이', answer: '비행기'),
    LineQuestion(prompt: '세면', answer: '도구'),
    LineQuestion(prompt: '음식물', answer: '쓰레기'),
    LineQuestion(prompt: '전자', answer: '레인지'),
    LineQuestion(prompt: '운동화', answer: '끈'),
    LineQuestion(prompt: '자외선', answer: '차단제'),
    LineQuestion(prompt: '주민', answer: '등록증'),
    LineQuestion(prompt: '학교', answer: '생활'),
    LineQuestion(prompt: '출발', answer: '신호'),
    LineQuestion(prompt: '냉동', answer: '만두'),
    LineQuestion(prompt: '아이스', answer: '크림'),
    LineQuestion(prompt: '아파트', answer: '단지'),
    LineQuestion(prompt: '자동차', answer: '보험'),
    LineQuestion(prompt: '휴대폰', answer: '충전기'),
  ],
  '속담': [
    LineQuestion(prompt: '가는 말이', answer: '고와야 오는 말이 곱다'),
    LineQuestion(prompt: '백지장도', answer: '맞들면 낫다'),
    LineQuestion(prompt: '티끌 모아', answer: '태산'),
    LineQuestion(prompt: '원숭이도', answer: '나무에서 떨어진다'),
    LineQuestion(prompt: '낮말은 새가 듣고', answer: '밤말은 쥐가 듣는다'),
    LineQuestion(prompt: '소 잃고', answer: '외양간 고친다'),
    LineQuestion(prompt: '등잔 밑이', answer: '어둡다'),
    LineQuestion(prompt: '금강산도', answer: '식후경'),
    LineQuestion(prompt: '꿩 먹고', answer: '알 먹기'),
    LineQuestion(prompt: '세 살 버릇', answer: '여든까지 간다'),
    LineQuestion(prompt: '호랑이도 제 말 하면', answer: '온다'),
    LineQuestion(prompt: '하늘의 별', answer: '따기'),
    LineQuestion(prompt: '돌다리도', answer: '두들겨 보고 건너라'),
    LineQuestion(prompt: '고래 싸움에', answer: '새우 등 터진다'),
    LineQuestion(prompt: '믿는 도끼에', answer: '발등 찍힌다'),
    LineQuestion(prompt: '우물 안', answer: '개구리'),
    LineQuestion(prompt: '발 없는 말이', answer: '천 리 간다'),
    LineQuestion(prompt: '그림의', answer: '떡'),
    LineQuestion(prompt: '열 번 찍어 안 넘어가는', answer: '나무 없다'),
    LineQuestion(prompt: '콩 심은 데 콩 나고', answer: '팥 심은 데 팥 난다'),
  ],
};

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
  String selectedCategory = '사자성어';
  LineGamePhase phase = LineGamePhase.setup;

  late List<int> scores;
  List<LineQuestion> questions = [];

  int teamIdx = 0;
  int questionIdx = 0;
  int remaining = lineGameSeconds;

  bool answerRevealed = false;
  bool saved = false;

  Timer? timer;

  @override
  void initState() {
    super.initState();
    final teams = context.read<SessionState>().teams;
    scores = List<int>.filled(teams.length, 0);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  LineQuestion get currentQuestion => questions[questionIdx];

  void _startGame() {
    final teams = context.read<SessionState>().teams;

    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 팀을 등록해 주세요.')),
      );
      return;
    }

    questions = List<LineQuestion>.of(
      lineQuestions[selectedCategory]!,
    )..shuffle();

    setState(() {
      scores = List<int>.filled(teams.length, 0);
      teamIdx = 0;
      questionIdx = 0;
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
        phase = LineGamePhase.ready;
      } else {
        phase = LineGamePhase.finished;
      }
    });
  }

  void _nextQuestion({required bool correct}) {
    if (phase != LineGamePhase.playing) return;

    setState(() {
      if (correct) {
        scores[teamIdx]++;
      }

      // 현재 문제 묶음을 다 풀면 다시 섞어 출제한다.
      if (questionIdx + 1 < questions.length) {
        questionIdx++;
      } else {
        questions.shuffle();
        questionIdx = 0;
      }

      answerRevealed = false;
    });
  }

  void _saveAndExit() {
    timer?.cancel();

    if (!saved && phase != LineGamePhase.setup) {
      context.read<SessionState>().addResult(
            GameResult(
              gameType: '줄줄이 말해요 - $selectedCategory',
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
        const SizedBox(height: 8),
        const Text('선택한 카테고리의 문제로 팀별 30초 동안 진행합니다.'),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: selectedCategory,
          decoration: const InputDecoration(
            labelText: '문제 카테고리',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final category in lineQuestions.keys)
              DropdownMenuItem(
                value: category,
                child: Text('$category (${lineQuestions[category]!.length}문제)'),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => selectedCategory = value);
            }
          },
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
            onPressed: _startGame,
            child: const Text('게임 시작'),
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
              selectedCategory,
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${team.name} 차례',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '$remaining초',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: remaining <= 10
                          ? Theme.of(context).colorScheme.error
                          : null,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: remaining / lineGameSeconds,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '현재 점수: ${scores[teamIdx]}점',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedCategory,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 20),
                      const Text('앞부분'),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currentQuestion.prompt,
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (answerRevealed) ...[
                        const Text('정답'),
                        const SizedBox(height: 8),
                        Text(
                          currentQuestion.answer,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => answerRevealed = true),
                          icon: const Icon(Icons.visibility),
                          label: const Text('정답 확인'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _nextQuestion(correct: true),
                  icon: const Icon(Icons.check),
                  label: const Text('정답 +1점'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 56),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _nextQuestion(correct: false),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('넘기기'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
