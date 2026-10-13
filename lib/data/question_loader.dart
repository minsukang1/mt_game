import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';

Future<List<QuizQuestion>> loadQuiz() async {
  final raw = await rootBundle.loadString('assets/questions/quiz.json');
  final list = jsonDecode(raw) as List;
  return list
      .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
      .toList();
}