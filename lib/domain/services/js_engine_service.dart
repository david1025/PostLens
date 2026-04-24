import 'dart:convert';
import 'package:flutter_js/flutter_js.dart';
import '../models/http_request_model.dart';
import '../models/http_response_model.dart';

typedef PlSendRequestHandler = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> options);

class JsEngineService {
  static final JsEngineService instance = JsEngineService._internal();
  JsEngineService._internal();

  Future<Map<String, dynamic>> executePreRequestScript(
    String script,
    HttpRequestModel request,
    Map<String, dynamic> environment, [
    Map<String, dynamic> globals = const {},
    Map<String, dynamic> collectionVariables = const {},
    PlSendRequestHandler? sendRequestHandler,
  ]) async {
    if (script.trim().isEmpty) {
      return {
        'request': request,
        'environment': environment,
        'globals': globals,
        'collectionVariables': collectionVariables,
      };
    }

    final jsRuntime = getJavascriptRuntime();
    
    jsRuntime.onMessage('plConsoleLog', (dynamic args) {
      
    });

    if (sendRequestHandler != null) {
      jsRuntime.onMessage('plSendRequest', (dynamic raw) async {
        try {
          final payload = jsonDecode(raw.toString());
          final id = payload['id']?.toString() ?? '';
          final options = (payload['options'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v),
              ) ??
              {};

          try {
            final res = await sendRequestHandler(
              options.map((k, v) => MapEntry(k, v)),
            );
            final resJson = jsonEncode(res);
            jsRuntime.evaluate(
                '_pl_callbacks["$id"](null, $resJson); _pl_pendingCount = Math.max(0, _pl_pendingCount - 1);');
          } catch (e) {
            final errJson = jsonEncode(e.toString());
            jsRuntime.evaluate(
                '_pl_callbacks["$id"]($errJson, null); _pl_pendingCount = Math.max(0, _pl_pendingCount - 1);');
          }
        } catch (_) {}
      });
    }

    final envJson = jsonEncode(environment);
    final globalsJson = jsonEncode(globals);
    final collectionVarsJson = jsonEncode(collectionVariables);
    final reqJson = jsonEncode(request.toJson());

    final setupScript = '''
      var console = {
        log: function() {
          var args = Array.prototype.slice.call(arguments);
          sendMessage('plConsoleLog', JSON.stringify(args));
        }
      };

      var _pl_env = $envJson;
      var _pl_globals = $globalsJson;
      var _pl_collection = $collectionVarsJson;
      var _pl_vars = {};
      var _pl_callbacks = {};
      var _pl_pendingCount = 0;
      var _pl_req = $reqJson;

      var pl = {
        environment: {
          get: function(key) { return _pl_env[key]; },
          set: function(key, value) { _pl_env[key] = value; },
          unset: function(key) { delete _pl_env[key]; },
          clear: function() { _pl_env = {}; }
        },
        variables: {
          get: function(key) { return _pl_vars[key]; },
          set: function(key, value) { _pl_vars[key] = value; },
          unset: function(key) { delete _pl_vars[key]; },
          clear: function() { _pl_vars = {}; }
        },
        globals: {
          get: function(key) { return _pl_globals[key]; },
          set: function(key, value) { _pl_globals[key] = value; },
          unset: function(key) { delete _pl_globals[key]; },
          clear: function() { _pl_globals = {}; }
        },
        collectionVariables: {
          get: function(key) { return _pl_collection[key]; },
          set: function(key, value) { _pl_collection[key] = value; },
          unset: function(key) { delete _pl_collection[key]; },
          clear: function() { _pl_collection = {}; }
        },
        sendRequest: function(options, callback) {
          if (typeof callback !== "function") {
            throw new Error("pl.sendRequest requires a callback");
          }
          var id = "" + Date.now() + Math.random();
          _pl_callbacks[id] = callback;
          _pl_pendingCount = _pl_pendingCount + 1;
          sendMessage('plSendRequest', JSON.stringify({id: id, options: options}));
        },
        request: _pl_req
      };
    ''';

    jsRuntime.evaluate(setupScript);
    
    try {
      jsRuntime.evaluate(script);
      
      if (sendRequestHandler != null) {
        final start = DateTime.now();
        while (true) {
          final pendingStr = jsRuntime.evaluate('_pl_pendingCount').stringResult;
          final pending = int.tryParse(pendingStr) ?? 0;
          if (pending <= 0) break;
          if (DateTime.now().difference(start).inSeconds >= 15) break;
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      final resultEnv = jsRuntime.evaluate('JSON.stringify(_pl_env)').stringResult;
      final resultGlobals = jsRuntime.evaluate('JSON.stringify(_pl_globals)').stringResult;
      final resultCollection =
          jsRuntime.evaluate('JSON.stringify(_pl_collection)').stringResult;
      final resultReq = jsRuntime.evaluate('JSON.stringify(pl.request)').stringResult;
      
      return {
        'request': HttpRequestModel.fromJson(jsonDecode(resultReq)),
        'environment': jsonDecode(resultEnv),
        'globals': jsonDecode(resultGlobals),
        'collectionVariables': jsonDecode(resultCollection),
      };
    } catch (e) {
      
      return {'request': request, 'environment': environment, 'error': e.toString()};
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () => jsRuntime.dispose());
    }
  }

  Future<Map<String, dynamic>> executeTests(
    String script,
    HttpRequestModel request,
    HttpResponseModel response,
    Map<String, dynamic> environment, [
    Map<String, dynamic> globals = const {},
    Map<String, dynamic> collectionVariables = const {},
    PlSendRequestHandler? sendRequestHandler,
  ]) async {
    if (script.trim().isEmpty) {
      return {
        'environment': environment,
        'globals': globals,
        'collectionVariables': collectionVariables,
        'testResults': [],
      };
    }

    final jsRuntime = getJavascriptRuntime();
    
    jsRuntime.onMessage('plConsoleLog', (dynamic args) {
      
    });

    if (sendRequestHandler != null) {
      jsRuntime.onMessage('plSendRequest', (dynamic raw) async {
        try {
          final payload = jsonDecode(raw.toString());
          final id = payload['id']?.toString() ?? '';
          final options = (payload['options'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v),
              ) ??
              {};

          try {
            final res = await sendRequestHandler(
              options.map((k, v) => MapEntry(k, v)),
            );
            final resJson = jsonEncode(res);
            jsRuntime.evaluate(
                '_pl_callbacks["$id"](null, $resJson); _pl_pendingCount = Math.max(0, _pl_pendingCount - 1);');
          } catch (e) {
            final errJson = jsonEncode(e.toString());
            jsRuntime.evaluate(
                '_pl_callbacks["$id"]($errJson, null); _pl_pendingCount = Math.max(0, _pl_pendingCount - 1);');
          }
        } catch (_) {}
      });
    }

    final envJson = jsonEncode(environment);
    final globalsJson = jsonEncode(globals);
    final collectionVarsJson = jsonEncode(collectionVariables);
    final reqJson = jsonEncode(request.toJson());
    final resJson = jsonEncode({
      'code': response.statusCode,
      'status': response.statusMessage,
      'body': response.body,
      'headers': response.headers,
      'responseTime': response.timeMs,
    });

    final setupScript = '''
      var console = {
        log: function() {
          var args = Array.prototype.slice.call(arguments);
          sendMessage('plConsoleLog', JSON.stringify(args));
        }
      };

      var _pl_env = $envJson;
      var _pl_globals = $globalsJson;
      var _pl_collection = $collectionVarsJson;
      var _pl_vars = {};
      var _pl_callbacks = {};
      var _pl_pendingCount = 0;
      var _pl_req = $reqJson;
      var _pl_res = $resJson;
      var _pl_testResults = [];
      var _pl_headers = {};
      if (_pl_res && _pl_res.headers) {
        Object.keys(_pl_res.headers).forEach(function(k) {
          _pl_headers[k.toLowerCase()] = _pl_res.headers[k];
        });
      }

      var pl = {
        environment: {
          get: function(key) { return _pl_env[key]; },
          set: function(key, value) { _pl_env[key] = value; },
          unset: function(key) { delete _pl_env[key]; },
          clear: function() { _pl_env = {}; }
        },
        variables: {
          get: function(key) { return _pl_vars[key]; },
          set: function(key, value) { _pl_vars[key] = value; },
          unset: function(key) { delete _pl_vars[key]; },
          clear: function() { _pl_vars = {}; }
        },
        globals: {
          get: function(key) { return _pl_globals[key]; },
          set: function(key, value) { _pl_globals[key] = value; },
          unset: function(key) { delete _pl_globals[key]; },
          clear: function() { _pl_globals = {}; }
        },
        collectionVariables: {
          get: function(key) { return _pl_collection[key]; },
          set: function(key, value) { _pl_collection[key] = value; },
          unset: function(key) { delete _pl_collection[key]; },
          clear: function() { _pl_collection = {}; }
        },
        sendRequest: function(options, callback) {
          if (typeof callback !== "function") {
            throw new Error("pl.sendRequest requires a callback");
          }
          var id = "" + Date.now() + Math.random();
          _pl_callbacks[id] = callback;
          _pl_pendingCount = _pl_pendingCount + 1;
          sendMessage('plSendRequest', JSON.stringify({id: id, options: options}));
        },
        request: _pl_req,
        response: {
          code: _pl_res.code,
          status: _pl_res.status,
          headers: _pl_headers,
          responseTime: _pl_res.responseTime,
          text: function() { return _pl_res.body; },
          json: function() { 
             try { return JSON.parse(_pl_res.body); } catch(e) { return {}; } 
          },
          header: function(name) {
            if (!name) return null;
            var v = _pl_headers[name.toLowerCase()];
            if (v == null) return null;
            if (Array.isArray(v)) return v.length ? v[0] : null;
            return v;
          }
        },
        test: function(name, func) {
          try {
            func();
            _pl_testResults.push({name: name, passed: true, error: null});
          } catch (e) {
            _pl_testResults.push({name: name, passed: false, error: e.message || e.toString()});
          }
        },
        expect: function(val) {
          return {
            to: {
              eql: function(expected) {
                if (val !== expected) throw new Error("Expected " + expected + " but got " + val);
              },
              be: {
                ok: function() { if (!val) throw new Error("Expected truthy but got " + val); }
              }
            }
          };
        }
      };
    ''';

    jsRuntime.evaluate(setupScript);

    try {
      jsRuntime.evaluate(script);

      if (sendRequestHandler != null) {
        final start = DateTime.now();
        while (true) {
          final pendingStr = jsRuntime.evaluate('_pl_pendingCount').stringResult;
          final pending = int.tryParse(pendingStr) ?? 0;
          if (pending <= 0) break;
          if (DateTime.now().difference(start).inSeconds >= 15) break;
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      final resultEnv = jsRuntime.evaluate('JSON.stringify(_pl_env)').stringResult;
      final resultGlobals = jsRuntime.evaluate('JSON.stringify(_pl_globals)').stringResult;
      final resultCollection =
          jsRuntime.evaluate('JSON.stringify(_pl_collection)').stringResult;
      final testResultsStr = jsRuntime.evaluate('JSON.stringify(_pl_testResults)').stringResult;
      
      return {
        'environment': jsonDecode(resultEnv),
        'globals': jsonDecode(resultGlobals),
        'collectionVariables': jsonDecode(resultCollection),
        'testResults': jsonDecode(testResultsStr),
      };
    } catch (e) {
      
      return {'environment': environment, 'testResults': [], 'error': e.toString()};
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () => jsRuntime.dispose());
    }
  }
}
