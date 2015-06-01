// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Provides hosting of `Shelf` handlers via App Engine.
library shelf_appengine;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart' as ae;
import 'package:mime/mime.dart' as mime;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Serves the provided [handler] using [ae.runAppEngine].
Future serve(Handler handler, {Function onError}) {
  return ae.runAppEngine((io.HttpRequest request) {
    shelf_io.handleRequest(request, handler);
  }, onError: onError);
}

/// Modes available to serve index files in directories.
class DirectoryIndexServeMode {
  /// When a directory URI is requested no special actions are taken. This
  /// usually end up in a 404 Not Found response.
  static const NONE = const DirectoryIndexServeMode._internal(0);

  /// When a directory URI is requested serve the index file directly in the
  /// response.
  static const SERVE = const DirectoryIndexServeMode._internal(1);

  /// When a directory URI is requested redirect to the index file with a
  /// `302 Found` response.
  static const REDIRECT = const DirectoryIndexServeMode._internal(2);

  /// When a directory URI is requested redirect to the index file with a
  /// `303 See Other` response.
  static const REDIRECT_SEE_OTHER = const DirectoryIndexServeMode._internal(3);

  /// When a directory URI is requested redirect to the index file with a
  /// `301 Moved Permanently` response.
  static const REDIRECT_PERMANENT = const DirectoryIndexServeMode._internal(4);

  final int _mode;

  const DirectoryIndexServeMode._internal(this._mode);
}

/// Serves files using [ae.context.assets].
///
/// You can choose how/if index files will be served when a directory URI is
/// requested by setting `directoryIndexServeMode`.
/// [DirectoryIndexServeMode.NONE] is the default. See
/// [DirectoryIndexServeMode] for more options.
/// The default name of the index files to serve can also be changed using
/// `indexFileName`. `index.html` is the default.
//TODO(kevmoo) better docs.
Handler assetHandler(
    {DirectoryIndexServeMode directoryIndexServeMode: DirectoryIndexServeMode.NONE,
    String indexFileName: "index.html"}) => (Request request) {
  var path = request.url.path;
  var indexPath = path + indexFileName;

  // If the path requested is a directory root we might serve an index.html
  // file depending on [directoryIndexServeMode].
  if (path.endsWith("/")) {
    if (directoryIndexServeMode == DirectoryIndexServeMode.SERVE) {
      path = indexPath;
    } else if (directoryIndexServeMode == DirectoryIndexServeMode.REDIRECT) {
      return new Response.found(indexPath);
    } else if (directoryIndexServeMode ==
        DirectoryIndexServeMode.REDIRECT_SEE_OTHER) {
      return new Response.seeOther(indexPath);
    } else if (directoryIndexServeMode ==
        DirectoryIndexServeMode.REDIRECT_PERMANENT) {
      return new Response.movedPermanently(indexPath);
    }
  }

  return ae.context.assets.read(path).then((stream) {
    Map headers;
    var contentType = mime.lookupMimeType(path);
    if (contentType != null) {
      headers = <String, String>{io.HttpHeaders.CONTENT_TYPE: contentType};
    }

    return new Response.ok(stream, headers: headers);
  }, onError: (err, stack) {
    ae.context.services.logging
        .error('Error getting asset at path $path\n$err\n$stack');
    // TODO(kevmoo): handle only the specific case of an asset not found
    // https://github.com/dart-lang/appengine/issues/7
    if (err is ae.AssetError) {
      return new Response.notFound('not found');
    }
    return new Future.error(err, stack);
  });
};
