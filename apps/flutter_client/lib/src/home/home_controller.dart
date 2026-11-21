import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lectale/src/course/course_providers.dart';
import 'package:lectale/src/course/import_failure.dart';
import 'package:lectale/src/home/github_address.dart';
import 'package:lectale/src/home/home_state.dart';

/// How long a request runs before the screen says it is slow.
const Duration slowImportAfter = Duration(seconds: 8);

/// How long to wait after a rate limit that named no wait (J5 rules: "Try
/// again in a minute").
const Duration defaultRateLimitWait = Duration(minutes: 1);

/// The Home screen's state and its two jobs: open a course, and cancel.
final NotifierProvider<HomeController, HomeState> homeControllerProvider =
    NotifierProvider.autoDispose<HomeController, HomeState>(HomeController.new);

/// Reads the typed address, imports the course and keeps the screen state.
class HomeController extends Notifier<HomeState> {
  // Each attempt gets a number; a late answer from an older one is dropped.
  int _attempt = 0;
  CancelToken? _request;
  Timer? _slowTimer;
  Timer? _waitTimer;

  @override
  HomeState build() {
    ref.onDispose(() {
      _stopRequest();
      _waitTimer?.cancel();
    });
    return const HomeIdle();
  }

  /// Opens the course at [typed]: checks the text, then asks the server.
  ///
  /// A request already running is cancelled and replaced. Ignored while a
  /// rate-limit wait runs, or after a failure that trying again can't help.
  Future<void> submit(String typed) async {
    final current = state;
    if (current is HomeFailure && !current.canSubmit) {
      return;
    }
    _stopRequest();
    _waitTimer?.cancel();
    final attempt = ++_attempt;

    final parsed = parseGitHubAddress(typed);
    if (parsed is AddressRejected) {
      state = HomeFailure(ImportInvalidAddress(parsed.issue));
      return;
    }

    final token = _request = CancelToken();
    state = const HomeLoading();
    _slowTimer = Timer(slowImportAfter, () {
      if (attempt == _attempt && state is HomeLoading) {
        state = const HomeLoading(slow: true);
      }
    });

    try {
      final preview = await ref
          .read(courseRepositoryProvider)
          .importCourse((parsed as AddressAccepted).url, cancelToken: token);
      if (attempt == _attempt && ref.mounted) {
        _slowTimer?.cancel();
        state = HomeSuccess(preview);
      }
    } on ImportCancelled {
      // The learner edited the address or pressed Escape; the state already
      // says so.
    } on ImportFailure catch (failure) {
      if (attempt == _attempt && ref.mounted) {
        _slowTimer?.cancel();
        _fail(failure);
      }
    }
  }

  /// Stops the running request and returns to the idle state. Used by Escape
  /// and by editing the address.
  void cancel() {
    if (state is! HomeLoading) {
      return;
    }
    _attempt++;
    _stopRequest();
    state = const HomeIdle();
  }

  /// Tells the controller the address text changed.
  ///
  /// Editing cancels a running request. It also lifts a block on Open course
  /// that only trying again blocked, because a new address is a new request;
  /// a rate-limit wait stays, because the limit is not about the address.
  void edited() {
    final current = state;
    if (current is HomeLoading) {
      cancel();
    } else if (current is HomeFailure &&
        !current.canSubmit &&
        current.failure is! ImportRateLimited) {
      state = HomeFailure(current.failure);
    }
  }

  void _fail(ImportFailure failure) {
    switch (failure) {
      case ImportRateLimited(:final retryAfter):
        state = HomeFailure(failure, canSubmit: false);
        _waitTimer = Timer(retryAfter ?? defaultRateLimitWait, () {
          if (ref.mounted) {
            state = HomeFailure(failure, waitOver: true);
          }
        });
      case ImportUnexpected(:final retryable):
        state = HomeFailure(failure, canSubmit: retryable);
      case _:
        state = HomeFailure(failure);
    }
  }

  void _stopRequest() {
    _slowTimer?.cancel();
    _request?.cancel('replaced');
    _request = null;
  }
}
