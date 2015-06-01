// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:shelf_appengine/shelf_appengine.dart' as shelf_ae;

/// This is a sample application.
///
/// It's in the bin directory to follow the convention of Dart applications.
void main() {
  shelf_ae.serve(shelf_ae.assetHandler());
}
