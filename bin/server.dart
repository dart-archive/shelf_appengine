// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:shelf/shelf.dart';
import 'package:shelf_appengine/shelf_appengine.dart' as shelf_ae;

void main() {
  shelf_ae.serve(_handler);
}

dynamic _handler(Request request) {
  var headers = {'Content-Type' : 'text/plain' };

  return new Response.ok('Hello from Shelf!', headers: headers);
}
