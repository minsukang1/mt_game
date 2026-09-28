import 'package:flutter/foundation.dart';
import '../models/game_result.dart';
import '../models/team.dart';

class SessionState extends ChangeNotifier {
  List<Team> teams = [];
  final List<GameResult> results = [];

  void startSession(List<Team> newTeams) {
    teams = newTeams;
    results.clear();
    notifyListeners();
  }

  void addResult(GameResult result) {
    results.add(result);
    notifyListeners();
  }

  List<int> get totals {
    final t = List<int>.filled(teams.length, 0);
    for (final r in results) {
      for (var i = 0; i < t.length; i++) {
        t[i] += r.scores[i];
      }
    }
    return t;
  }
}