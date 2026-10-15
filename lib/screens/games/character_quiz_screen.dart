
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/session_state.dart';
import '../../models/game_result.dart';

class CharacterQuizScreen extends StatefulWidget {
  const CharacterQuizScreen({super.key});

  @override
  State<CharacterQuizScreen> createState() =>
      _CharacterQuizScreenState();
}

class _CharacterQuizScreenState extends State<CharacterQuizScreen> {
  List<dynamic> _questions = [];

  // 현재 문제 번호와 진행 팀
  int _questionIndex = 0;
  int _teamIndex = 0;

  // 팀별 정답 수
  List<int> _scores = [];

  bool _showAnswer = false;
  bool _answered = false;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // JSON 문제 데이터 불러오기
  Future<void> _loadQuestions() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/questions/character_quiz.json',
      );

      final List<dynamic> data = jsonDecode(jsonString);

      if (!mounted) return;

      final session = context.read<SessionState>();

      setState(() {
        _questions = data;
        _scores = List<int>.filled(session.teams.length, 0);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // 현재 문제
  Map<String, dynamic> get _currentQuestion =>
      Map<String, dynamic>.from(_questions[_questionIndex]);

  // 정답 처리: 문제당 한 번만 점수 부여
  void _markCorrect() {
    if (_answered || _finished) return;

    setState(() {
      _scores[_teamIndex]++;
      _answered = true;
      _showAnswer = true;
    });
  }

  // 정답 공개
  void _revealAnswer() {
    setState(() {
      _showAnswer = true;
    });
  }

  // 다음 문제로 이동
  void _nextQuestion() {
    if (_questionIndex >= _questions.length - 1) {
      _finishGame();
      return;
    }

    setState(() {
      _questionIndex++;
      _showAnswer = false;
      _answered = false;
    });
  }

  // 게임 점수 저장
  void _finishGame() {
    if (_finished) return;

    _finished = true;

    context.read<SessionState>().addResult(
      GameResult(
        gameType: '인물퀴즈',
        scores: List<int>.from(_scores),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('인물퀴즈')),
        body: const Center(
          child: Text(
            '문제 데이터를 불러오지 못했습니다.\n'
            'assets/questions/character_quiz.json을 확인해 주세요.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 참여 팀이 없는 경우
    if (session.teams.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('인물퀴즈')),
        body: const Center(child: Text('먼저 팀을 설정해 주세요.')),
      );
    }

    final question = _currentQuestion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('인물퀴즈'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단: 진행 상황과 팀 선택
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    '${_questionIndex + 1} / ${_questions.length} 문제',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Text('진행 팀 '),
                  DropdownButton<int>(
                    value: _teamIndex,
                    items: List.generate(
                      session.teams.length,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text('${index + 1}팀'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _teamIndex = value);
                    },
                  ),
                ],
              ),
            ),

            // 중앙: 인물 사진
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    question['image'] as String,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              size: 100,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '사진을 등록해 주세요',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 정답은 버튼을 눌러야 공개
            Text(
              _showAnswer
                  ? question['name'] as String
                  : '이 인물의 이름은?',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              '현재 ${_teamIndex + 1}팀 정답: '
              '${_scores[_teamIndex]}개',
              style: const TextStyle(fontSize: 16),
            ),

            // 하단: 진행 버튼
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _showAnswer ? null : _revealAnswer,
                      child: const Text('정답 공개'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _answered ? null : _markCorrect,
                      child: const Text('정답 +1점'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      child: Text(
                        _questionIndex == _questions.length - 1
                            ? '게임 종료'
                            : '다음 문제',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
