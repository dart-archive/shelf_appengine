// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library shelf_appengine;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart' as ae;
import 'package:mime/mime.dart' as mime;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future serve(Handler handler, {Function onError}) {
  return ae.runAppEngine((io.HttpRequest request) {
    shelf_io.handleRequest(request, handler);
  }, onError: onError);
}

final Handler assetHandler = _assetHandler;

_assetHandler(Request request) {
  var path = request.url.path;

  return ae.context.assets.read(path).then((stream) {
    Map headers;
    var contentType = mime.lookupMimeType(path);
    if (contentType != null) {
      headers = <String, String>{io.HttpHeaders.CONTENT_TYPE: contentType};
    }

    return new Response.ok(stream, headers: headers);
  }, onError: (err, stack) {
    // TODO(kevmoo): handle only the specific case of an asset not found
    // https://github.com/dart-lang/appengine/issues/7
    if (err is ae.AssetError) {
      return new Response.notFound('not found');
    }
    return new Future.error(err, stack);
  });
}
