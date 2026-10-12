import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Data beranda dari GET /dashboard (isi berbeda per peran).
final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.watch(apiClientProvider).get('/dashboard');
  return res['data'] as Map<String, dynamic>;
});
