import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'token_storage.dart';

/// Kesalahan dari API yang sudah diterjemahkan ke pesan yang bisa ditampilkan.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors = const {}});

  final String message;
  final int? statusCode;

  /// Error validasi per field, misal {'password': ['Password minimal 6 karakter.']}
  final Map<String, List<String>> errors;

  bool get isUnauthorized => statusCode == 401;

  String? fieldError(String field) => errors[field]?.first;

  @override
  String toString() => message;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;

    if (response == null) {
      return ApiException(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'Koneksi ke server terlalu lama. Coba lagi.',
        _ => 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      });
    }

    final data = response.data;
    final status = response.statusCode;
    var message = switch (status) {
      401 => 'Sesi Anda telah berakhir. Silakan masuk kembali.',
      403 => 'Anda tidak memiliki akses ke fitur ini.',
      404 => 'Data tidak ditemukan.',
      429 => 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
      int s when s >= 500 => 'Terjadi gangguan di server. Coba beberapa saat lagi.',
      _ => 'Terjadi kesalahan. Coba lagi.',
    };
    final errors = <String, List<String>>{};

    if (data is Map) {
      if (data['message'] is String && (data['message'] as String).isNotEmpty && status != 500) {
        message = data['message'] as String;
      }
      if (data['errors'] is Map) {
        (data['errors'] as Map).forEach((key, value) {
          errors['$key'] = value is List ? value.map((v) => '$v').toList() : ['$value'];
        });
      }
    }

    return ApiException(message, statusCode: status, errors: errors);
  }
}

/// File yang akan diunggah (dari kamera, galeri, atau penyimpanan).
class UploadFile {
  const UploadFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Dio dengan token otomatis dan pesan error berbahasa Indonesia.
class ApiClient {
  ApiClient(this._tokens, {void Function()? onUnauthorized})
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.read();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (e, handler) {
          final isLogin = e.requestOptions.path.endsWith('/login');
          if (e.response?.statusCode == 401 && !isLogin) onUnauthorized?.call();
          handler.next(e);
        },
      ),
    );
  }

  final TokenStorage _tokens;
  final Dio dio;

  Future<T> _send<T>(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? data}) => _send(() => dio.post(path, data: data));

  Future<Map<String, dynamic>> put(String path, {Object? data}) => _send(() => dio.put(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _send(() => dio.delete(path));

  /// Unggah file (multipart/form-data).
  Future<Map<String, dynamic>> upload(String path, Map<String, Object?> fields) {
    final form = FormData();
    fields.forEach((key, value) {
      if (value == null) return;
      if (value is UploadFile) {
        form.files.add(MapEntry(key, MultipartFile.fromBytes(value.bytes, filename: value.name)));
      } else {
        form.fields.add(MapEntry(key, '$value'));
      }
    });
    return _send(() => dio.post(path, data: form));
  }

  /// Unduh file yang dilindungi login (foto, dokumen) sebagai bytes.
  Future<Uint8List> getBytes(String url) async {
    try {
      final res = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Header untuk Image.network pada file yang dilindungi login (foto santri, bukti bayar).
  Map<String, String> get authHeaders {
    final token = _tokens.current;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }
}

/// Dipanggil saat token ditolak server; callback diisi oleh AuthController.
class UnauthorizedHandler {
  void Function()? callback;
}

final unauthorizedHandlerProvider = Provider<UnauthorizedHandler>((ref) => UnauthorizedHandler());

final apiClientProvider = Provider<ApiClient>((ref) {
  final handler = ref.watch(unauthorizedHandlerProvider);
  return ApiClient(
    ref.watch(tokenStorageProvider),
    onUnauthorized: () => handler.callback?.call(),
  );
});
