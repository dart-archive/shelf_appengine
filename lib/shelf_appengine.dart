// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Provides hosting of `Shelf` handlers via App Engine.
library shelf_appengine;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart' as ae;
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Serves the provided [handler] using [ae.runAppEngine].
///
/// If [port] is not provided or `null`, `8080` is used.
Future serve(Handler handler, {int port, Function onError}) {
  if (port == null) port = 8080;
  return ae.runAppEngine((io.HttpRequest request) {
    shelf_io.handleRequest(request, handler);
  }, onError: onError, port: port);
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
        {DirectoryIndexServeMode directoryIndexServeMode:
            DirectoryIndexServeMode.NONE,
        String indexFileName: "index.html"}) =>
    (Request request) async {
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
        } else if (directoryIndexServeMode ==
            DirectoryIndexServeMode.REDIRECT) {
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

      try {
        var stream = await ae.context.assets.read(path);

        Map headers;
        var contentType = mime.lookupMimeType(path);
        if (contentType != null) {
          headers = <String, String>{io.HttpHeaders.CONTENT_TYPE: contentType};
        }

        return new Response.ok(stream, headers: headers);
      } catch (err, stack) {
        ae.context.services.logging
            .error('Error getting asset at path $path\n$err\n$stack');
        // TODO(kevmoo): handle only the specific case of an asset not found
        // https://github.com/dart-lang/appengine/issues/7
        if (err is ae.AssetError) {
          return new Response.notFound('not found');
        }
        rethrow;
      }
    };
