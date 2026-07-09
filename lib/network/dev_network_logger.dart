import 'package:dio/dio.dart';
import 'package:venera/foundation/appdata.dart';

/// A single captured HTTP request/response for the developer panel.
class DevNetLog {
  final String method;
  final String url;
  final int? statusCode;
  final int? durationMs;
  final String? error;
  final DateTime time;

  DevNetLog({
    required this.method,
    required this.url,
    this.statusCode,
    this.durationMs,
    this.error,
    required this.time,
  });
}

/// Ring buffer of the most recent network requests. Capped so memory stays flat.
final List<DevNetLog> devNetLogs = [];

const int _maxNetLogs = 300;

/// Captures HTTP traffic (method, url, status, duration) into [devNetLogs].
///
/// Only records while "Developer Mode" ([lab_developerMode]) is enabled, so it
/// is a no-op for normal users. Added to [AppDio]'s interceptors; it never
/// blocks or alters a request.
class DeveloperNetworkLogger extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (appdata.settings['lab_developerMode'] != true) {
      handler.next(options);
      return;
    }
    options.extra['_devStart'] = DateTime.now().microsecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _record(response.requestOptions, response.statusCode, null);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(err.requestOptions, err.response?.statusCode, err.message);
    handler.next(err);
  }

  void _record(RequestOptions options, int? statusCode, String? error) {
    final start = options.extra['_devStart'] as int?;
    final durationMs = start == null
        ? null
        : (DateTime.now().microsecondsSinceEpoch - start) ~/ 1000;
    devNetLogs.add(
      DevNetLog(
        method: options.method,
        url: options.uri.toString(),
        statusCode: statusCode,
        durationMs: durationMs,
        error: error,
        time: DateTime.now(),
      ),
    );
    if (devNetLogs.length > _maxNetLogs) {
      devNetLogs.removeRange(0, devNetLogs.length - _maxNetLogs);
    }
  }
}
