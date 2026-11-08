import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visor_config/repositories/document_repository.dart';
import 'package:visor_config/services/isolate_job.dart';
import 'package:visor_config/services/json_parser.dart';
import 'package:visor_config/services/document_search.dart';

int neverFinishes(Object? _) {
  while (true) {}
}

class GrowingFile extends XFile {
  GrowingFile() : super('growing.json');
  @override
  Future<int> length() async => 1;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    final chunk = Uint8List(1024 * 1024);
    for (var i = 0; i < 33; i++) {
      yield chunk;
    }
  }
}

void main() {
  test('Cancels and times out background work', () async {
    final timeout = IsolateJob<int>(
      neverFinishes,
      null,
      const Duration(milliseconds: 50),
    );
    await expectLater(timeout.result, throwsA(isA<TimeoutException>()));
    final cancelled = IsolateJob<int>(
      neverFinishes,
      null,
      const Duration(seconds: 10),
    );
    final completed = expectLater(cancelled.result, throwsStateError);
    cancelled.cancel();
    await completed;
  });

  test('Rejects excessive nesting before decoding, including schemas', () {
    final nested = ['[' * 300, '0', ']' * 300].join();
    expect(
      parseDocument({'text': nested, 'schema': '', 'standard': 'JSON Schema'})
          .error,
      contains('limit'),
    );
    final result = parseDocument({
      'text': '{}',
      'schema': nested,
      'standard': 'JSON Schema',
    });
    expect(result.issues.single, contains('limit'));
  });

  test('Bounds search results and streaming reads', () async {
    expect(searchText('a' * 20000, [], 'a'), hasLength(10001));
    await expectLater(
      DocumentRepository().read(GrowingFile()),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('Atomic replacement retains Linux ACL', () async {
    if (!Platform.isLinux || !File('/usr/bin/setfacl').existsSync()) return;
    final directory = await Directory.systemTemp.createTemp('visor-acl-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/document.json');
    await file.writeAsString('{}');
    final acl = await Process.run('/usr/bin/setfacl', [
      '-m',
      'u:65534:r--,g::---,m::r--',
      file.path,
    ]);
    expect(acl.exitCode, 0);
    final before = await Process.run('/usr/bin/getfacl', ['-cp', file.path]);
    await DocumentRepository().write(file.path, [123, 125, 10]);
    final after = await Process.run('/usr/bin/getfacl', ['-cp', file.path]);
    expect(after.stdout, before.stdout);
    expect(await file.readAsString(), '{}\n');
  });
}
