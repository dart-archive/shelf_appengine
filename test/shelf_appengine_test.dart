// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:unittest/unittest.dart';

final _serverUri = Uri.parse('http://localhost:8080');

void main() {
  group('DirectoryIndexServeMode', () {
    _testMode('default', path: '/', dirCode: 404);
    _testMode('module-serve', dirCode: 200);
    _testMode('module-redirect', dirCode: 302);
  });
}

void _testMode(String mode, {String path, int dirCode: 500}) {
  if (path == null) {
    path = "${mode}/";
  }

  group(mode, () {
    test("Request 'dir'", () async {
      var target = _serverUri.resolve(path);
      var statusCode = await _getNoRedirect(target);

      expect(statusCode, dirCode);
    });

    test("Request index.html", () async {
      var target = _serverUri.resolve(path + 'index.html');
      var statusCode = await _getNoRedirect(target);
      expect(statusCode, 200);
    });
  });
}

Future<int> _getNoRedirect(Uri uri) async {
  var client = new http.IOClient();
  try {
    var request = new http.Request('GET', uri)..followRedirects = false;
    var streamedResponse = await client.send(request);
    return streamedResponse.statusCode;
  } finally {
    client.close();
  }
}
