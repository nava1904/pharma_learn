// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assessment_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AssessmentStore on _AssessmentStoreBase, Store {
  Computed<Question?>? _$currentQuestionComputed;

  @override
  Question? get currentQuestion =>
      (_$currentQuestionComputed ??= Computed<Question?>(
        () => super.currentQuestion,
        name: '_AssessmentStoreBase.currentQuestion',
      )).value;
  Computed<int>? _$totalQuestionsComputed;

  @override
  int get totalQuestions => (_$totalQuestionsComputed ??= Computed<int>(
    () => super.totalQuestions,
    name: '_AssessmentStoreBase.totalQuestions',
  )).value;
  Computed<int>? _$answeredQuestionsComputed;

  @override
  int get answeredQuestions => (_$answeredQuestionsComputed ??= Computed<int>(
    () => super.answeredQuestions,
    name: '_AssessmentStoreBase.answeredQuestions',
  )).value;
  Computed<double>? _$progressComputed;

  @override
  double get progress => (_$progressComputed ??= Computed<double>(
    () => super.progress,
    name: '_AssessmentStoreBase.progress',
  )).value;
  Computed<bool>? _$isFirstQuestionComputed;

  @override
  bool get isFirstQuestion => (_$isFirstQuestionComputed ??= Computed<bool>(
    () => super.isFirstQuestion,
    name: '_AssessmentStoreBase.isFirstQuestion',
  )).value;
  Computed<bool>? _$isLastQuestionComputed;

  @override
  bool get isLastQuestion => (_$isLastQuestionComputed ??= Computed<bool>(
    () => super.isLastQuestion,
    name: '_AssessmentStoreBase.isLastQuestion',
  )).value;
  Computed<bool>? _$canSubmitComputed;

  @override
  bool get canSubmit => (_$canSubmitComputed ??= Computed<bool>(
    () => super.canSubmit,
    name: '_AssessmentStoreBase.canSubmit',
  )).value;
  Computed<bool>? _$isTimerExpiredComputed;

  @override
  bool get isTimerExpired => (_$isTimerExpiredComputed ??= Computed<bool>(
    () => super.isTimerExpired,
    name: '_AssessmentStoreBase.isTimerExpired',
  )).value;
  Computed<String>? _$formattedTimeRemainingComputed;

  @override
  String get formattedTimeRemaining =>
      (_$formattedTimeRemainingComputed ??= Computed<String>(
        () => super.formattedTimeRemaining,
        name: '_AssessmentStoreBase.formattedTimeRemaining',
      )).value;
  Computed<bool>? _$isAttemptActiveComputed;

  @override
  bool get isAttemptActive => (_$isAttemptActiveComputed ??= Computed<bool>(
    () => super.isAttemptActive,
    name: '_AssessmentStoreBase.isAttemptActive',
  )).value;

  late final _$isLoadingAtom = Atom(
    name: '_AssessmentStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_AssessmentStoreBase.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$availableAssessmentsAtom = Atom(
    name: '_AssessmentStoreBase.availableAssessments',
    context: context,
  );

  @override
  ObservableList<Assessment> get availableAssessments {
    _$availableAssessmentsAtom.reportRead();
    return super.availableAssessments;
  }

  @override
  set availableAssessments(ObservableList<Assessment> value) {
    _$availableAssessmentsAtom.reportWrite(
      value,
      super.availableAssessments,
      () {
        super.availableAssessments = value;
      },
    );
  }

  late final _$currentAttemptAtom = Atom(
    name: '_AssessmentStoreBase.currentAttempt',
    context: context,
  );

  @override
  AssessmentAttempt? get currentAttempt {
    _$currentAttemptAtom.reportRead();
    return super.currentAttempt;
  }

  @override
  set currentAttempt(AssessmentAttempt? value) {
    _$currentAttemptAtom.reportWrite(value, super.currentAttempt, () {
      super.currentAttempt = value;
    });
  }

  late final _$questionsAtom = Atom(
    name: '_AssessmentStoreBase.questions',
    context: context,
  );

  @override
  ObservableList<Question> get questions {
    _$questionsAtom.reportRead();
    return super.questions;
  }

  @override
  set questions(ObservableList<Question> value) {
    _$questionsAtom.reportWrite(value, super.questions, () {
      super.questions = value;
    });
  }

  late final _$currentQuestionIndexAtom = Atom(
    name: '_AssessmentStoreBase.currentQuestionIndex',
    context: context,
  );

  @override
  int get currentQuestionIndex {
    _$currentQuestionIndexAtom.reportRead();
    return super.currentQuestionIndex;
  }

  @override
  set currentQuestionIndex(int value) {
    _$currentQuestionIndexAtom.reportWrite(
      value,
      super.currentQuestionIndex,
      () {
        super.currentQuestionIndex = value;
      },
    );
  }

  late final _$answersAtom = Atom(
    name: '_AssessmentStoreBase.answers',
    context: context,
  );

  @override
  ObservableMap<String, dynamic> get answers {
    _$answersAtom.reportRead();
    return super.answers;
  }

  @override
  set answers(ObservableMap<String, dynamic> value) {
    _$answersAtom.reportWrite(value, super.answers, () {
      super.answers = value;
    });
  }

  late final _$timeRemainingSecondsAtom = Atom(
    name: '_AssessmentStoreBase.timeRemainingSeconds',
    context: context,
  );

  @override
  int? get timeRemainingSeconds {
    _$timeRemainingSecondsAtom.reportRead();
    return super.timeRemainingSeconds;
  }

  @override
  set timeRemainingSeconds(int? value) {
    _$timeRemainingSecondsAtom.reportWrite(
      value,
      super.timeRemainingSeconds,
      () {
        super.timeRemainingSeconds = value;
      },
    );
  }

  late final _$isSubmittingAtom = Atom(
    name: '_AssessmentStoreBase.isSubmitting',
    context: context,
  );

  @override
  bool get isSubmitting {
    _$isSubmittingAtom.reportRead();
    return super.isSubmitting;
  }

  @override
  set isSubmitting(bool value) {
    _$isSubmittingAtom.reportWrite(value, super.isSubmitting, () {
      super.isSubmitting = value;
    });
  }

  late final _$resultAtom = Atom(
    name: '_AssessmentStoreBase.result',
    context: context,
  );

  @override
  AssessmentResult? get result {
    _$resultAtom.reportRead();
    return super.result;
  }

  @override
  set result(AssessmentResult? value) {
    _$resultAtom.reportWrite(value, super.result, () {
      super.result = value;
    });
  }

  late final _$loadAvailableAssessmentsAsyncAction = AsyncAction(
    '_AssessmentStoreBase.loadAvailableAssessments',
    context: context,
  );

  @override
  Future<void> loadAvailableAssessments() {
    return _$loadAvailableAssessmentsAsyncAction.run(
      () => super.loadAvailableAssessments(),
    );
  }

  late final _$startAttemptAsyncAction = AsyncAction(
    '_AssessmentStoreBase.startAttempt',
    context: context,
  );

  @override
  Future<bool> startAttempt(String assessmentId) {
    return _$startAttemptAsyncAction.run(
      () => super.startAttempt(assessmentId),
    );
  }

  late final _$saveAnswerAsyncAction = AsyncAction(
    '_AssessmentStoreBase.saveAnswer',
    context: context,
  );

  @override
  Future<void> saveAnswer(String questionId, dynamic answer) {
    return _$saveAnswerAsyncAction.run(
      () => super.saveAnswer(questionId, answer),
    );
  }

  late final _$submitAssessmentAsyncAction = AsyncAction(
    '_AssessmentStoreBase.submitAssessment',
    context: context,
  );

  @override
  Future<bool> submitAssessment({
    required String esigPassword,
    required String meaning,
  }) {
    return _$submitAssessmentAsyncAction.run(
      () =>
          super.submitAssessment(esigPassword: esigPassword, meaning: meaning),
    );
  }

  late final _$loadResultAsyncAction = AsyncAction(
    '_AssessmentStoreBase.loadResult',
    context: context,
  );

  @override
  Future<void> loadResult(String attemptId) {
    return _$loadResultAsyncAction.run(() => super.loadResult(attemptId));
  }

  late final _$_AssessmentStoreBaseActionController = ActionController(
    name: '_AssessmentStoreBase',
    context: context,
  );

  @override
  void goToQuestion(int index) {
    final _$actionInfo = _$_AssessmentStoreBaseActionController.startAction(
      name: '_AssessmentStoreBase.goToQuestion',
    );
    try {
      return super.goToQuestion(index);
    } finally {
      _$_AssessmentStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void nextQuestion() {
    final _$actionInfo = _$_AssessmentStoreBaseActionController.startAction(
      name: '_AssessmentStoreBase.nextQuestion',
    );
    try {
      return super.nextQuestion();
    } finally {
      _$_AssessmentStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void previousQuestion() {
    final _$actionInfo = _$_AssessmentStoreBaseActionController.startAction(
      name: '_AssessmentStoreBase.previousQuestion',
    );
    try {
      return super.previousQuestion();
    } finally {
      _$_AssessmentStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void updateTimer(int seconds) {
    final _$actionInfo = _$_AssessmentStoreBaseActionController.startAction(
      name: '_AssessmentStoreBase.updateTimer',
    );
    try {
      return super.updateTimer(seconds);
    } finally {
      _$_AssessmentStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void decrementTimer() {
    final _$actionInfo = _$_AssessmentStoreBaseActionController.startAction(
      name: '_AssessmentStoreBase.decrementTimer',
    );
    try {
      return super.decrementTimer();
    } finally {
      _$_AssessmentStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void reset() {
    final _$actionInfo = _$_AssessmentStoreBaseActionController.startAction(
      name: '_AssessmentStoreBase.reset',
    );
    try {
      return super.reset();
    } finally {
      _$_AssessmentStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_AssessmentStoreBaseActionController.startAction(
      name: '_AssessmentStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_AssessmentStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
availableAssessments: ${availableAssessments},
currentAttempt: ${currentAttempt},
questions: ${questions},
currentQuestionIndex: ${currentQuestionIndex},
answers: ${answers},
timeRemainingSeconds: ${timeRemainingSeconds},
isSubmitting: ${isSubmitting},
result: ${result},
currentQuestion: ${currentQuestion},
totalQuestions: ${totalQuestions},
answeredQuestions: ${answeredQuestions},
progress: ${progress},
isFirstQuestion: ${isFirstQuestion},
isLastQuestion: ${isLastQuestion},
canSubmit: ${canSubmit},
isTimerExpired: ${isTimerExpired},
formattedTimeRemaining: ${formattedTimeRemaining},
isAttemptActive: ${isAttemptActive}
    ''';
  }
}
