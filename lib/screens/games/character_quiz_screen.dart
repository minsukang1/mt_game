
import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
  // 문제 데이터
  List<Map<String, dynamic>> _allQuestions = [];
  bool _loading = true;
  String? _loadError;

  // 게임 설정
  final Set<int> _selectedTeamIndexes = {};
  final Set<String> _selectedDifficulties = {
    '쉬움',
    '보통',
    '어려움',
  };
  final Set<String> _selectedCategories = {};

  int _questionsPerTeam = 5;
  int _timerSeconds = 10;

  // 실제 게임 진행 상태
  final Map<int, List<Map<String, dynamic>>> _teamQuestions = {};
  final List<int> _scores = [];

  int _teamPosition = 0;
  int _questionPosition = 0;
  int _remainingSeconds = 0;

  bool _started = false;
  bool _revealed = false;
  bool _timeUp = false;
  bool _saving = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 기본값은 모든 팀 참여
    final teams = context.read<SessionState>().teams;
    _selectedTeamIndexes.addAll(
      List.generate(teams.length, (index) => index),
    );

    _scores.addAll(List<int>.filled(teams.length, 0));

    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // JSON 문제 데이터 읽기
  Future<void> _loadQuestions() async {
    try {
      final jsonText = await rootBundle.loadString(
        'assets/questions/character_quiz.json',
      );

      final decoded = jsonDecode(jsonText);

      if (decoded is! List) {
        throw const FormatException('JSON 최상위 데이터는 배열이어야 합니다.');
      }

      final questions = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) =>
              item['name'] != null &&
              item['image'] != null &&
              item['difficulty'] != null &&
              item['category'] != null)
          .toList();

      if (!mounted) return;

      setState(() {
        _allQuestions = questions;
        _selectedCategories.addAll(
          questions
              .map((q) => q['category'].toString())
              .toSet(),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadError = '문제 파일을 불러오지 못했습니다.\n$e';
        _loading = false;
      });
    }
  }

  // 현재 설정에 맞는 문제 목록
  List<Map<String, dynamic>> get _filteredQuestions {
    return _allQuestions.where((question) {
      final difficulty = question['difficulty'].toString();
      final category = question['category'].toString();

      return _selectedDifficulties.contains(difficulty) &&
          _selectedCategories.contains(category);
    }).toList();
  }

  // 게임 시작
  void _startGame() {
    final session = context.read<SessionState>();
    final selectedTeams = _selectedTeamIndexes.toList()..sort();

    if (selectedTeams.isEmpty) {
      _showMessage('참여할 팀을 한 팀 이상 선택해 주세요.');
      return;
    }

    if (_selectedDifficulties.isEmpty) {
      _showMessage('난이도를 하나 이상 선택해 주세요.');
      return;
    }

    if (_selectedCategories.isEmpty) {
      _showMessage('카테고리를 하나 이상 선택해 주세요.');
      return;
    }

    // 모든 팀이 공유하는 문제 목록을 섞는다.
    final questions = List<Map<String, dynamic>>.from(
      _filteredQuestions,
    )..shuffle(Random());

    final requiredCount =
        selectedTeams.length * _questionsPerTeam;

    // 팀 간 중복 없이 진행할 수 있는 문제 수 확인
    if (questions.length < requiredCount) {
      _showMessage(
        '선택한 조건에 맞는 문제가 ${questions.length}개뿐입니다.\n'
        '현재 설정에는 최소 $requiredCount개가 필요합니다.\n'
        '문제 수를 줄이거나 난이도·카테고리를 더 선택해 주세요.',
      );
      return;
    }

    _teamQuestions.clear();

    // 섞인 문제를 팀별로 나눈다.
    // 이미 배정한 문제는 다른 팀에 배정하지 않는다.
    var questionIndex = 0;

    for (final teamIndex in selectedTeams) {
      _teamQuestions[teamIndex] = questions
          .skip(questionIndex)
          .take(_questionsPerTeam)
          .toList();

      questionIndex += _questionsPerTeam;
    }

    setState(() {
      _started = true;
      _teamPosition = 0;
      _questionPosition = 0;
      _remainingSeconds = _timerSeconds;
      _revealed = false;
      _timeUp = false;

      // 이번 게임에 참여하지 않는 팀의 점수는 0점
      for (var i = 0; i < session.teams.length; i++) {
        _scores[i] = 0;
      }
    });

    _startTimer();
  }

  // 문제 제한 시간 시작
  void _startTimer() {
    _timer?.cancel();

    setState(() {
      _remainingSeconds = _timerSeconds;
      _revealed = false;
      _timeUp = false;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_remainingSeconds <= 1) {
          timer.cancel();

          setState(() {
            _remainingSeconds = 0;
            _timeUp = true;
            _revealed = true;
          });
        } else {
          setState(() {
            _remainingSeconds--;
          });
        }
      },
    );
  }

  // 정답 공개
  void _revealAnswer() {
    _timer?.cancel();

    setState(() {
      _revealed = true;
    });
  }

  // 정답이면 점수를 추가하고 다음 문제로 이동
  void _answerQuestion(bool correct) {
    if (_timeUp) return;

    _timer?.cancel();

    if (correct) {
      final teamIndex = _currentTeamIndex;
      _scores[teamIndex]++;
    }

    _nextQuestion();
  }

  // 다음 문제 또는 다음 팀으로 이동
  void _nextQuestion() {
    _timer?.cancel();

    final currentTeamQuestions =
        _teamQuestions[_currentTeamIndex]!;

    if (_questionPosition + 1 < currentTeamQuestions.length) {
      setState(() {
        _questionPosition++;
      });

      _startTimer();
      return;
    }

    // 현재 팀의 문제가 모두 끝났으면 다음 팀으로 이동
    if (_teamPosition + 1 < _teamQuestions.length) {
      setState(() {
        _teamPosition++;
        _questionPosition = 0;
      });

      _startTimer();
      return;
    }

    // 모든 팀 종료
    _finishGame();
  }

  // 게임 결과 저장
  void _finishGame() {
    if (_saving) return;

    _timer?.cancel();

    setState(() {
      _saving = true;
    });

    context.read<SessionState>().addResult(
      GameResult(
        gameType: '인물퀴즈',
        scores: List<int>.from(_scores),
      ),
    );

    Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int get _currentTeamIndex {
    return _teamQuestions.keys.elementAt(_teamPosition);
  }

  Map<String, dynamic> get _currentQuestion {
    return _teamQuestions[_currentTeamIndex]![_questionPosition];
  }

  String _teamName(int index) {
    return context.read<SessionState>().teams[index].name;
  }

  // 설정 화면의 선택 버튼
  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  // 설정 화면
  Widget _buildSettings() {
    final teams = context.watch<SessionState>().teams;

    if (teams.isEmpty) {
      return const Center(
        child: Text('먼저 팀을 생성해 주세요.'),
      );
    }

    final categories = _allQuestions
        .map((q) => q['category'].toString())
        .toSet()
        .toList()
      ..sort();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '인물 퀴즈 설정',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '참여 팀과 출제 조건을 정한 뒤 게임을 시작하세요.',
          ),
          const SizedBox(height: 24),

          // 팀 선택
          const Text(
            '1. 참여 팀 선택',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < teams.length; i++)
                _choiceChip(
                  label: teams[i].name,
                  selected: _selectedTeamIndexes.contains(i),
                  onSelected: () {
                    setState(() {
                      if (!_selectedTeamIndexes.add(i)) {
                        _selectedTeamIndexes.remove(i);
                      }
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 20),

          // 난이도 선택
          const Text(
            '2. 난이도 선택',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final difficulty in ['쉬움', '보통', '어려움'])
                _choiceChip(
                  label: difficulty,
                  selected: _selectedDifficulties.contains(difficulty),
                  onSelected: () {
                    setState(() {
                      if (!_selectedDifficulties.add(difficulty)) {
                        _selectedDifficulties.remove(difficulty);
                      }
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 20),

          // 카테고리 선택
          const Text(
            '3. 카테고리 선택',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('문제 데이터에 등록된 카테고리가 없습니다.'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _choiceChip(
                  label: '전체 선택',
                  selected:
                      _selectedCategories.length == categories.length,
                  onSelected: () {
                    setState(() {
                      if (_selectedCategories.length ==
                          categories.length) {
                        _selectedCategories.clear();
                      } else {
                        _selectedCategories
                          ..clear()
                          ..addAll(categories);
                      }
                    });
                  },
                ),
                for (final category in categories)
                  _choiceChip(
                    label: category,
                    selected: _selectedCategories.contains(category),
                    onSelected: () {
                      setState(() {
                        if (!_selectedCategories.add(category)) {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                  ),
              ],
            ),

          const SizedBox(height: 20),

          // 팀당 문제 수
          const Text(
            '4. 팀당 문제 수',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _questionsPerTeam,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '팀마다 출제할 문제 수',
            ),
            items: [3, 5, 10, 15, 20, 30]
                .map(
                  (count) => DropdownMenuItem(
                    value: count,
                    child: Text('$count문제'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _questionsPerTeam = value;
                });
              }
            },
          ),

          const SizedBox(height: 20),

          // 타이머
          const Text(
            '5. 문제당 제한 시간',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _timerSeconds,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '한 문제 제한 시간',
            ),
            items: [1,3,5,10]
                .map(
                  (seconds) => DropdownMenuItem(
                    value: seconds,
                    child: Text('$seconds초'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _timerSeconds = value;
                });
              }
            },
          ),

          const SizedBox(height: 16),

          Text(
            '선택한 조건에 맞는 문제: ${_filteredQuestions.length}개\n'
            '필요한 문제: '
            '${_selectedTeamIndexes.length * _questionsPerTeam}개',
            style: const TextStyle(fontSize: 15),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                '게임 시작',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 실제 퀴즈 화면
  Widget _buildGame() {
    final question = _currentQuestion;
    final teamIndex = _currentTeamIndex;
    final teamQuestions = _teamQuestions[teamIndex]!;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _teamName(teamIndex),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_teamPosition + 1}/${_teamQuestions.length}팀',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: (_questionPosition + 1) / teamQuestions.length,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '문제 ${_questionPosition + 1} / ${teamQuestions.length}',
            style: const TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 8),

          Text(
            _timeUp ? '시간 종료!' : '남은 시간: $_remainingSeconds초',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _remainingSeconds <= 5
                  ? Colors.red
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          // 이미지가 화면 밖으로 잘리지 않도록 남은 공간에 맞춤
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      question['image'].toString(),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_not_supported, size: 48),
                              SizedBox(height: 8),
                              Text('이미지를 불러올 수 없습니다.'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (_revealed)
                    Text(
                      '정답: ${question['name']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_revealed)
                  FilledButton(
                    onPressed: _revealAnswer,
                    child: const Text('정답 공개'),
                  )
                else if (_timeUp)
                  FilledButton(
                    onPressed: _nextQuestion,
                    child: const Text('다음 문제'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _answerQuestion(true),
                          child: const Text('정답 +1점'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _answerQuestion(false),
                          child: const Text('오답 / 다음 문제'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('인물 퀴즈'),
        leading: _started
            ? const SizedBox.shrink()
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_loadError!),
                  ),
                )
              : _started
                  ? _buildGame()
                  : _buildSettings(),
    );
  }
}
