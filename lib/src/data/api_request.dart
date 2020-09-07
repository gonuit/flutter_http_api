part of http_api;

// ignore_for_file: unnecessary_getters_setters

class ApiRequest {
  // TODO: Add automatic key generation
  CacheKey _key;

  /// Identifies (groups) requests.
  ///
  /// Used for caching purposes - as cache key.
  CacheKey get key => _key;
  set key(CacheKey value) => _key = value;

  final _id = ObjectId();

  /// Id of current ApiRequest
  ObjectId get id => _id;

  /// ApiRequest object creation timestamp.
  DateTime get createdAt => id.timestamp;

  /// Url is set by BaseApi class
  Uri _apiUrl;
  Uri get apiUrl => _apiUrl;
  Uri get url {
    if (apiUrl == null) {
      throw ApiError("url is not available before sending a request");
    }

    final queryParameters = Map<String, dynamic>.from(apiUrl.queryParameters)
      ..addAll(this.queryParameters);

    return Uri(
      scheme: apiUrl.scheme,
      host: apiUrl.host,
      path: apiUrl.path + endpoint,
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
      port: apiUrl.port,
    );
  }

  String endpoint;
  HttpMethod method;
  Encoding encoding;
  bool _multipart;
  dynamic body;

  /// Here you can assign your data that will be passed to the next link
  final Map<String, dynamic> linkData = {};
  final List<FileField> fileFields = [];
  final Map<String, String> headers = {};
  final Map<String, dynamic> queryParameters = {};

  /// If [BaseApiRequest] contains files or [multipart] property is set to true
  /// [isMultipart] equals true
  bool get isMultipart => _multipart == true || fileFields.isNotEmpty;

  ApiRequest({
    @required this.endpoint,
    this.method = HttpMethod.get,
    Map<String, String> headers,
    List<FileField> fileFields,
    Map<String, dynamic> queryParameters,
    this.body,
    this.encoding,
    bool multipart,
    @experimental CacheKey key,
  })  : _key = key,
        _multipart = multipart,
        assert(
          endpoint != null && method != null,
          "endpoint and method arguments cannot be null",
        ) {
    if (fileFields != null) this.fileFields.addAll(fileFields);
    if (headers != null) this.headers.addAll(headers);
    if (queryParameters != null) this.queryParameters.addAll(queryParameters);
  }

  /// Builds http request from ApiRequest data
  FutureOr<http.BaseRequest> build() {
    if (url == null) {
      throw ApiError(
        "$runtimeType url cannot be null. Instead of calling build method, "
        "pass ApiRequest to BaseApi: 'send' method.",
      );
    }
    return isMultipart ? _buildMultipartHttpRequest() : _buildHttpRequest();
  }

  /// Builds [MultipartRequest]
  Future<http.BaseRequest> _buildMultipartHttpRequest() async {
    final request = http.MultipartRequest(method.value, url)
      ..headers.addAll(headers);

    /// Assign body if it is map
    if (body != null) {
      if (body is Map) {
        request.fields.addAll(body.cast<String, String>());
      } else {
        throw ArgumentError(
          'Invalid request body "$body".\n'
          'Multipart request body should be Map<String, String>',
        );
      }
    }

    /// Assign files to [MultipartRequest]
    for (final fileField in fileFields) {
      request.files.add(await fileField.toMultipartFile());
    }

    return request;
  }

  /// Buils [Request]
  http.BaseRequest _buildHttpRequest() {
    final request = http.Request(method.value, url);

    if (headers != null) request.headers.addAll(headers);
    if (encoding != null) request.encoding = encoding;
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List) {
        request.bodyBytes = body.cast<int>();
      } else if (body is Map) {
        request.bodyFields = body.cast<String, String>();
      } else {
        throw ArgumentError('Invalid request body "$body".');
      }
    }
    return request;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        "url": url,
        "body": body,
        "encoding": encoding,
        "fileFields": fileFields,
        "headers": headers,
        "linkData": linkData,
        "method": method.value,
        "isMultipart": isMultipart,
      };

  String toString() => "$runtimeType(${toMap()})";

  String toJson() {
    return jsonEncode(<String, dynamic>{
      "id": id.hexString,
      if (key != null) "key": key.value,
      "createdAt": createdAt.toIso8601String(),
      if (apiUrl != null) "apiUrl": apiUrl.toString(),
      if (apiUrl != null) "url": url.toString(),
      "endpoint": endpoint,
      "method": method.value,
      "isMultipart": isMultipart,
      "body": body,
      "headers": headers,
      "queryParameters": queryParameters,
      // TODO:
      // if(encoding != null) "encoding": encoding.toString(),
      // "fileFields": fileFields,
    });
  }
}