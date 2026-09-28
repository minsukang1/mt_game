class GameResult {
  final String gameType;
  final List<int> scores; // 팀 순서대로 점수

  GameResult({required this.gameType, required this.scores});
}