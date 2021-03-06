import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http_server/http_server.dart';
import '../../get_server.dart';
import '../logger/log.dart';
import '../routes/route.dart';

class GetPage {
  final Method method;
  final String name;
  final List<String> keys;
  final GetView page;

  GetPage({
    this.method = Method.get,
    this.name = '/',
    this.page,
    this.keys,
  });
}

Future<GetServer> runApp(GetServer server) {
  return server.start();
}

class GetServer {
  final LogWriterCallback log;
  final List<GetPage> getPages;
  final String host;
  final int port;
  final String certificateChain;
  final bool shared;
  final String privateKey;
  final String password;
  final bool cors;
  final List<Route> _routes = <Route>[];
  HttpServer _server;
  VirtualDirectory _staticServer;

  GetServer({
    this.host = '127.0.0.1',
    this.port = 8080,
    this.certificateChain,
    this.privateKey,
    this.password,
    this.shared = false,
    this.getPages,
    this.cors = false,
    this.log = logger,
  });

  void stop() => _server.close();

  Future<GetServer> start() {
    if (getPages != null) {
      getPages.forEach((route) {
        _routes.add(Route(route.method, route.name, route.page.build,
            keys: route.keys));
      });
    }

    if (privateKey != null) {
      var context = SecurityContext();
      if (certificateChain != null) {
        context.useCertificateChain(File(certificateChain).path);
      }
      context.usePrivateKey(File(privateKey).path, password: password);
      return HttpServer.bindSecure(host, port, context, shared: shared)
          .then(_configure);
    }
    return HttpServer.bind(host, port, shared: shared).then(_configure);
  }

  void addCorsHeaders(HttpResponse response) {
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers
        .add('Access-Control-Allow-Methods', 'GET,HEAD,PUT,PATCH,POST,DELETE');
    response.headers.add('Access-Control-Allow-Headers',
        'access-control-allow-origin,content-type,x-access-token');
  }

  FutureOr<GetServer> _configure(HttpServer httpServer) {
    _server = httpServer;
    httpServer.listen((req) {
      if (cors) {
        addCorsHeaders(req.response);
        if (req.method.toLowerCase() == 'options') {
          var msg = {"status": "ok"};
          req.response.write(json.encode(msg));
          req.response.close();
        }
      }
      var route =
          _routes.firstWhere((route) => route.match(req), orElse: () => null);
      if (route != null) {
        route.handle(req);
      } else if (_staticServer != null) {
        _staticServer.serveRequest(req);
      } else {
        pageNotFound(req);
      }
    });

    log('Server started on $host:$port');

    return this;
  }

  void get(String path, FutureOr build(Context context), {List<String> keys}) {
    _routes.add(Route(Method.get, path, build, keys: keys));
  }

  void post(String path, FutureOr build(Context context), {List<String> keys}) {
    _routes.add(Route(Method.post, path, build, keys: keys));
  }

  void delete(String path, FutureOr build(Context context),
      {List<String> keys}) {
    _routes.add(Route(Method.delete, path, build, keys: keys));
  }

  void put(String path, FutureOr build(Context context), {List<String> keys}) {
    _routes.add(Route(Method.put, path, build, keys: keys));
  }

  void ws(String path, FutureOr build(Context context), {List<String> keys}) {
    _routes.add(Route(Method.ws, path, build, keys: keys));
  }

  void pageNotFound(HttpRequest req) {
    req.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }
}

abstract class GetView {
  FutureOr build(Context context);
}
