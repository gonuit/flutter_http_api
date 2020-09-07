# http_api
  
![Tests](https://github.com/gonuit/flutter_http_api/workflows/Tests/badge.svg?event=status)
![Pub Version](https://img.shields.io/pub/v/http_api?color=%230175c2)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
  
Simple yet powerful wrapper around http package inspired by apollo graphql links. This package provides you a simple way of adding interceptors to your app http requests.

## IMPORTANT
This library is under development, breaking API changes might still happen. If you would like to make use of this library please make sure to provide which version you want to use e.g:
```yaml
dependencies:
  http_api: 0.7.0
```

## Getting Started

#### 1. Create your Api class by extending `BaseApi` class.
```dart
// define your api class
class Api extends BaseApi {

  /// Provide the BaseApi constructor with the data you need,
  /// by calling super method.
  Api(Uri url) : super(url);

  /// Implement api request methods...
  Future<PostModel> getPostById(int id) async {

    /// Use [send] method to make api request
    final response = await send(ApiRequest(
      endpoint: "/posts/$id",
    ));

    /// Do something with your data. 
    /// e.g: Parse HTTP response to the model of your choice.
    return PostModel.fromJson(response.body);
  }
}
```

#### 2. Play with it!
```dart
void main() async {
  /// Define api base url.
  final url = Uri.parse("https://example.com/api");

  /// Create api instance
  final api = Api(url);
  
  /// Make a request
  Post post = await api.getPostById(10);

  /// Do something with your data 🚀
  print(post.title);

  /// After all.
  api.dispose();

  /// 🔥 You are ready for rocking! 🔥
}
```

## http_api and Flutter ♥️.
http_api package works well with both Dart and Flutter projects.

#### TIP: You can provide your Api instance down the widget tree using [provider](https://pub.dev/packages/provider) package.
```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    return Provider(
        create: (_) => Api(
          Uri.parse("https://example.com/api"),
        ),
        /// Your app
        child: MaterialApp(
          title: 'my_app',
          onGenerateRoute: _generateRoute,
        ),
      );
  }
}
```

## ApiLinks (Interceptors / Middleware)
Api links allow you to perform certain tasks before the request and after the response from the API (HTTP client).

### To add interceptors to your api instance.
```dart
void main() {
  Api(
    Uri.parse("https://example.com/api"),
    /// Assign interceptors by providing ApiLinks (to provide more than one interceptors, chain them)
    link: AuthLink()
        .chain(DebugLink(responseBody: true)),
        .chain(HttpLink()),
  )
}
```
#### How will it work?
When performing a request via `send` (or `cacheAndNetwork` and `cacheIfAvailable`). The request will travers api links chain to reach `HttpLink` which must be the last link. HttpLink calls API by making a request. Then all links are receiving api response before it is returned in place of the send method invocation. Look at the below diagram.
```
                                 __________               ____________               __________
calling send()    |  -request-> | AuthLink |  -request-> | LoggerLink |  -request-> | HttpLink |
send returns data | <-response- |__________| <-response- |____________| <-response- |__________|
                                    tasks                     tasks                 http request   
```
#### Custom api link implementation (Create own interceptor).
```dart
/// Create link class and extends [ApiLink].
class CustomLink extends ApiLink {

  /// Override next method.
  @override
  Future<ApiResponse> next(ApiRequest request) async {
    /// Here you can do actions that will take place before
    /// sending http request.
    /// e.g: Measure request duration.
    final requestTime = DateTime.now();

    /// Calling super.next invokes next ApiLinks.
    /// This can be thought of as sending an HTTP request.
    ApiResponse response = await super.next(request);

    /// This part of the code will be called after receiving a
    /// response from the API.
    /// e.g: We can print request duration.

    final requestDuration = DateTime.now().difference(requestTime);

    print(
      "Request ${request.id} duration: "
      "${responseDuration.inMilliseconds} ms\n",
    );

    /// Provide prevoius link with response.
    /// This can be thought of as returning from APIs' `send` method.
    return response;
  }
}
```
If your link operates on data that should be disposed of together with api instance. You can override its `dispose` method.

## Cache
With http_api you can cache your responses to avoid uneccesary fetches or/and improve user experience.
  
### To add cache to your existing Api class.
#### 1. Add `Cache` mixin on it.
```diff
- class Api extends BaseApi {
+ class Api extends BaseApi with Cache {

  /// ** your custom Api class implementation **
}
```
#### 2. Provide a Api class with cache manager of your choice.
```dart
class Api extends BaseApi with Cache {

  /// Provide a cache manager of your choice.
  /// This lib provides you with in memory cache manager implementation.
  @override
  CacheManager createCacheManager() => InMemoryCache();

  /// ** Your custom Api class implementation **
}
```
#### 3. That's all!
Now you can take advantage of response caching.
  
### Cache mixin.
Cache mixin adds `cacheAndNetwork` and `cacheIfAvailable` methods to your api instance, together with the cache manager which is accessible via `cache` property.
  
By default, each request that contains `key` argument for which response was successful; will automatically update the cache. To decide what should be saved into the cache, override `shouldUpdateCache` method.

#### `cacheIfAvailable`
Retrieve response from the cache,  if not available fallback to the network.  
Returns `Future<ApiResponse>` type.

#### `cacheAndNetwork`
Retrieve response from the cache if available and then from the network.  Returns `Stream<ApiResponse>` type.
  
Example:
```dart
// Api.dart
class Api extends BaseApi with Cache {

  @override
  CacheManager createCacheManager() => InMemoryCache();

  Stream<PostModel> getPostById(int id) {
    Stream<PostModel> request = ApiRequest(
      /// Key argument is required for caching.
      /// Response will be cached and retrieved from the following key.
      key: CacheKey("posts/$id"),
      endpoint: "/posts/${id}",
    );
    
    /// Because `cacheAndNetwork` method returns Stream, we can take
    /// advantage of all it's features.
    /// e.g: Transform responses to the models of your choice.
    final transformResponseToPostModel =
        StreamTransformer<ApiResponse, PostModel>.fromHandlers(
      handleData: (response, sink) => sink.add(
        PostModel.fromJson(response.body),
      ),
    );

    /// Now you can return transformed stream from this function
    return cacheAndNetwork(request)
        .transform(transformResponseToPostModel);
  }

  /// ** Your custom Api class implementation **
}
```

#### `cache`
Cache property contains a `CacheManager` instance that was internally created via the `createCacheManager` method. Thanks to this property, you can manipulate your cache by yourself.
  
Example:
```dart
/// Saves a new response to the cache and retrieve previously saved.
ApiResponse saveResponseToCache(CacheKey key, ApiResponse response) async {
  final oldResponse = await api.cache.read(key);
  await api.cache.write(key, response);
  return oldResponse;
}
```

#### `shouldUpdateCache` 
Decide whether response related to request should be saved to the cache.

Default implementation:
```dart
bool shouldUpdateCache(ApiRequest request, ApiResponse response) {
 return request.key != null && response.ok;
}
```
  
## TODO:
- Improve documentation
  - Improve readme file
  - Add devtools