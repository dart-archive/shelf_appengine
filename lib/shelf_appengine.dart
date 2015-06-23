// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Provides hosting of `Shelf` handlers via App Engine.
library shelf_appengine;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart' as ae;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:stack_trace/stack_trace.dart';

/// Serves the provided [handler] using [ae.runAppEngine].
Future serve(Handler handler, {Function onError}) {
  handler = _wrap(handler);
  return ae.runAppEngine((io.HttpRequest request) {
    Chain.capture(() {
      shelf_io.handleRequest(request, handler);
    }, onError: (error, chain) {
      if (error is UnsupportedError) {
        // Very specific to the implementation in AppEngine
        if (error.message == "You cannot detach the socket from "
            "AppengineHttpResponse implementation.") {
          return;
        }
      }
      throw error;
    });
  }, onError: onError);
}

Handler _wrap(Handler source) {
  return (Request request) async {
    var response = await source(request);

    if (response is AppEngineAssetResponse) {
      ae.context.assets.serve(response._desiredPath);

      // This causes a fast-fail without writing to the response – 
      // it requires catching the UnsupportedError in `serve` above
      request.hijack((a, b) {
        // Intentional NOOP
      });
    }
    return response;
  };
}

/// Modes available to serve index files in directories.
enum DirectoryIndexServeMode {
  /// When a directory URI is requested no special actions are taken. This
  /// usually end up in a 404 Not Found response.
  NONE,

  /// When a directory URI is requested serve the index file directly in the
  /// response.
  SERVE,

  /// When a directory URI is requested redirect to the index file with a
  /// `302 Found` response.
  REDIRECT,

  /// When a directory URI is requested redirect to the index file with a
  /// `303 See Other` response.
  REDIRECT_SEE_OTHER,

  /// When a directory URI is requested redirect to the index file with a
  /// `301 Moved Permanently` response.
  REDIRECT_PERMANENT
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
    String indexFileName: "index.html"}) => (Request request) async {
  var path = request.url.path;
  var indexPath = p.join(path, indexFileName);

  bool isBarePath = false;
  if (path.isEmpty) {
    isBarePath = request.handlerPath.endsWith('/');
  } else if (path.endsWith('/')) {
    isBarePath = true;
  }

  // If the path requested is a directory root we might serve an index.html
  // file depending on [directoryIndexServeMode].
  if (isBarePath) {
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

  // When serving off the file system, the appengine AssetManager just joins
  // the root with the path w/ '+' – need to make sure that's a clean concat
  // TODO(kevmoo) should likely open an issue on this.
  if (!path.startsWith('/')) {
    path = '/' + path;
  }

  return new AppEngineAssetResponse._(path);
};

class AppEngineAssetResponse implements Response {
  final String _desiredPath;

  int get statusCode => 200;

  AppEngineAssetResponse._(this._desiredPath);

  noSuchMethod(Invocation inv) {
    throw new UnsupportedError('This response designed to pass through'
        ' to the root handler. You cannot access its data in middleware.');
  }
}
