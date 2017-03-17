// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:scheduled_test/scheduled_test.dart';
import 'package:scheduled_test/descriptor.dart' as d;

import 'package:shelf_appengine/shelf_appengine.dart';

Stream<String> _getLines(Stream<List<int>> stdout) =>
    stdout.transform(SYSTEM_ENCODING.decoder).transform(const LineSplitter());

const _defaultPubServeHost = 'http://192.168.59.3:7777';
const _pubServeEnvKey = "DART_PUB_SERVE";

Uri _serverUri;

void main() {
  _runModes(false);

  group('with pub serve', () {
    _runModes(true);
  });
}

void _runModes(bool withPubServe) {
  group('default value (same as none)', () {
    _runTest(null, 404, withPubServe);
  });

  group('none', () {
    _runTest(DirectoryIndexServeMode.NONE, 404, withPubServe);
  });

  group('serve', () {
    _runTest(DirectoryIndexServeMode.SERVE, 200, withPubServe);
  });

  group('redirect', () {
    _runTest(DirectoryIndexServeMode.REDIRECT, 302, withPubServe);
  });
}

void _runTest(DirectoryIndexServeMode mode, int dirCode, bool withPubServe) {
  Directory tempDir;
  Process appEngineProcess;
  Process pubServeProcess;

  String workingDir() => p.join(tempDir.path, 'pkg');

  setUp(() {
    // set up the dir
    schedule(() async {
      var dir = await Directory.systemTemp.createTemp('shelf_appengine.test.');

      tempDir = dir;
      d.defaultRoot = tempDir.path;
    });

    schedule(() async {
      d.dir('pkg', [
        d.file('Dockerfile', _dockerFile),
        d.file('app.yaml', _getAppYaml(withPubServe)),
        d.file('pubspec.yaml', _pubspecYaml),
        d.dir('bin', [d.file('server.dart', _getServerCode(mode))]),
        d.dir('build', [
          d.dir('web', [d.file('index.html', _indexHtml)])
        ])
      ]).create();
    });

    // pub build
    schedule(() {
      var result = Process.runSync('pub', ['install', '--offline'],
          workingDirectory: workingDir());

      expect(result.exitCode, 0);
    });

    schedule(() async {
      var hostPort = await _getOpenPort();
      var defaultHost = 'localhost:$hostPort';

      var adminPort = await _getOpenPort();
      var adminHost = 'localhost:$adminPort';

      appEngineProcess = await Process.start(
          'gcloud',
          [
            '--project',
            'shelf-appengine-test',
            'preview',
            'app',
            'run',
            'app.yaml',
            '--host',
            defaultHost,
            '--admin-host',
            adminHost
          ],
          workingDirectory: workingDir());

      var waitingForNext = false;

      Completer answerCompleter = new Completer();

      StreamSubscription sub;

      sub = _getLines(appEngineProcess.stderr).listen((line) {
        print(line);
        if (answerCompleter.isCompleted) return;

        if (line.startsWith('ERROR:')) {
          answerCompleter.completeError(line);
          sub.cancel();
          return;
        }

        if (line.contains('New instance for module "default" serving on:')) {
          waitingForNext = true;
        } else if (waitingForNext) {
          answerCompleter.complete(line);

          // NOTE: comment out this cancel to see what's going on
          // sub.cancel();
        }
      });

      _serverUri = Uri.parse(await answerCompleter.future);
    });
    // TODO: wait for the right output?

    // TODO: kill pub server, if we're doing that

    currentSchedule.onComplete.schedule(() async {
      if (appEngineProcess != null) {
        int rootPid = appEngineProcess.pid;

        // NOW! *sigh* go looking for child processes of the just kill process
        var result = Process.runSync('ps', ['-o', 'pid, ppid']);

        if (result.exitCode == 0) {
          //print([result.stdout, result.stderr]);

          var parentTree = new Map<int, Set<int>>();

          for (var match in _pidRegexp.allMatches(result.stdout)) {
            var pid = int.parse(match[1]);
            var ppid = int.parse(match[2]);

            var parentSet = parentTree.putIfAbsent(ppid, () => new Set<int>());
            parentSet.add(pid);
          }

          //print(parentTree);

          var toKill = new LinkedHashSet<int>();
          var toProcess = <int>[rootPid];

          //print("root pid: $rootPid");

          while (toProcess.isNotEmpty) {
            var current = toProcess.removeLast();
            toKill.add(current);

            var kids = parentTree[current];

            if (kids == null) {
              continue;
            }

            toProcess.addAll(kids);
          }

          //print(toKill);

          for (var pid in toKill) {
            //print('killing $pid');
            var output = Process.killPid(pid);
            expect(output, isTrue);
            //print('Success: $output');
          }
        }

        // print("waiting for things to die...");
        await appEngineProcess.exitCode;
        appEngineProcess = null;
      }

      if (pubServeProcess != null) {
        pubServeProcess.kill(ProcessSignal.SIGTERM);

        await pubServeProcess.exitCode;
      }

      d.defaultRoot = null;
      return tempDir.delete(recursive: true);
    });
  });

  test("Request 'dir'", () {
    schedule(() async {
      var target = _serverUri.resolve('/');
      var statusCode = await _getNoRedirect(target);
      expect(statusCode, dirCode);
    });

    schedule(() async {
      var target = _serverUri.resolve('/index.html');
      var statusCode = await _getNoRedirect(target);
      expect(statusCode, 200);
    });
  }, timeout: new Timeout(const Duration(minutes: 3)));
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

String _getServerCode(DirectoryIndexServeMode mode) {
  String modeText;

  if (mode == null) {
    modeText = '';
  } else {
    switch (mode) {
      case DirectoryIndexServeMode.NONE:
        modeText = 'directoryIndexServeMode: DirectoryIndexServeMode.NONE';
        break;
      case DirectoryIndexServeMode.SERVE:
        modeText = 'directoryIndexServeMode: DirectoryIndexServeMode.SERVE';
        break;
      case DirectoryIndexServeMode.REDIRECT:
        modeText = 'directoryIndexServeMode: DirectoryIndexServeMode.REDIRECT';
        break;
      default:
        throw 'Not supported - $mode';
    }
  }

  return '''
import 'package:shelf_appengine/shelf_appengine.dart';

void main() {
  serve(assetHandler(${modeText}));
}
''';
}

// TODO: should make the shared port thing correct-ish
String _getAppYaml(bool usePubServe) {
  var env = '';

  if (usePubServe) {
    var envValue = Platform.environment[_pubServeEnvKey];

    if (envValue == null) {
      print('$_pubServeEnvKey not set. Using default: $_defaultPubServeHost');
      envValue = _defaultPubServeHost;
    } else {
      print('Using ENV $_pubServeEnvKey - $envValue');
    }

    env = '''
env_variables:
  DART_PUB_SERVE: $envValue
  ''';
  }

  return '''
runtime: custom
vm: true
api_version: 1
${env}''';
}

const _pubspecYaml = r'''
name: _test_pkg
version: 0.2.0
dependencies:
  shelf_appengine: any
''';

const _indexHtml = r'''
<html><body>hello</body></html>''';

const _dockerFile = r'''FROM google/dart-runtime''';

var _pidRegexp = new RegExp(r'(\d+)\s+(\d+)');

/// Returns an open port by creating a temporary Socket
Future<int> _getOpenPort() async {
  ServerSocket socket;

  try {
    socket = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  } catch (_) {
    // try again v/ V6 only. Slight possibility that V4 is disabled
    socket = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V6, 0,
        v6Only: true);
  }

  try {
    return socket.port;
  } finally {
    await socket.close();
  }
}
