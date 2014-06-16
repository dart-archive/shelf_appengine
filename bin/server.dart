// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_appengine/shelf_appengine.dart' as shelf_ae;
import 'package:appengine/appengine.dart' as ae;

void main() {
  shelf_ae.serve(_handler);
}

Future<Response> _handler(Request request) {
  var appEngineContext = request.context[shelf_ae.CONTEXT_KEY_APPENGINE]
      as ae.ClientContext;

  var memcache = appEngineContext.services.memcache;

  var headers = {'Content-Type' : 'text/plain' };

  var memcacheKey = 'count-${request.requestedUri}';

  return memcache.increment(memcacheKey).then((value) {
    var body = '''Hello from Shelf
Requested url: ${request.requestedUri}
Count: $value''';

    return new Response.ok(body, headers: headers);
  });
}
