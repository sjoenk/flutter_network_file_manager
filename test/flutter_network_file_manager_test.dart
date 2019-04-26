import 'dart:io';

import 'package:flutter_network_file_manager/src/file_object.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // Tests with sqflite are broken, because sqflite doesn't provide testing yet.
  test('Test adding files to cache sql store', () async {
    String url = "https://cdn2.online-convert.com/example-file/raster%20image/png/example_small.png";
    String name = "small_example";
    DateTime timestamp = DateTime.parse("2019-01-01 10:00:00");
    var provider = await getDbProvider();
    await provider.open();
    await provider.updateOrInsert(FileObject(
      name: name,
      url: url,
      timestamp: timestamp,
    ));
    await provider.close();

    await provider.open();
    var storedObject = await provider.get(url);
    expect(storedObject, isNotNull);
    expect(storedObject.id, isNotNull);
  });
}

Future<FileObjectProvider> getDbProvider() async {
  var storeKey = 'test';

  var databasesPath = await Directory.systemTemp.createTemp();
  var path = p.join(databasesPath.path, "$storeKey.db");

  try {
    await Directory(databasesPath.path).create(recursive: true);
  } catch (_) {}
  return FileObjectProvider(path);
}
