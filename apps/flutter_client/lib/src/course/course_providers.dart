import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lectale/src/app/api_config.dart';
import 'package:lectale/src/course/course_repository.dart';

/// The API's root address. Fails with [MissingApiBaseUrl] on a native build
/// that was started without one.
final apiBaseUrlProvider = Provider<String>((ref) => resolveApiBaseUrl());

/// The one HTTP client of the app. Tests replace it with a client whose
/// adapter answers from memory.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: ref.watch(apiBaseUrlProvider)));
  ref.onDispose(dio.close);
  return dio;
});

/// Opens public courses.
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(dioProvider)),
);
