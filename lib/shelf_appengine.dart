// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_appengine;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart' as ae;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const String CONTEXT_KEY_APPENGINE = 'shelf_appengine.context';

Future serve(Handler handler, {Function onError}) {
  return ae.runAppEngine((io.HttpRequest request) {
    shelf_io.handleRequest(request, (innerRequest) {
      var appengineContext = ae.contextFromRequest(request);
      var ctx = { CONTEXT_KEY_APPENGINE: appengineContext };
      innerRequest = innerRequest.change(context: ctx);
      return handler(innerRequest);
    });
  }, onError: onError);
}
