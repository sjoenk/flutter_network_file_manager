import 'package:sqflite/sqflite.dart';
import 'package:meta/meta.dart';

class FileObject {
  static const String tableFileObject = "fileObject";

  static const String columnId = "_id";
  static const String columnName = "name";
  static const String columnUrl = "url";
  static const String columnPath = "relativePath";
  static const String columnETag = "eTag";
  static const String columnTimestamp = "timestamp";
  static const String columnTouchedAt = "touchedAt";

  int id;
  String name;
  String url;
  String relativePath;
  String eTag;
  DateTime timestamp;
  DateTime touchedAt;

  FileObject({
    @required this.name,
    this.url,
    this.id,
    this.relativePath,
    this.eTag,
    this.timestamp,
    this.touchedAt,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      columnName: name,
      columnUrl: url,
      columnPath: relativePath,
      columnETag: eTag,
      columnTimestamp: timestamp.millisecondsSinceEpoch,
      columnTouchedAt: DateTime.now().millisecondsSinceEpoch,
    };
    if (id != null) {
      map[columnId] = id;
    }
    return map;
  }

  FileObject.fromMap(Map<String, dynamic> map) {
    id = map[columnId];
    name = map[columnName];
    url = map[columnUrl];
    relativePath = map[columnPath];
    eTag = map[columnETag];
    timestamp = DateTime.fromMillisecondsSinceEpoch(map[columnTimestamp]);
    touchedAt = DateTime.fromMillisecondsSinceEpoch(map[columnTouchedAt]);
  }

  static List<FileObject> fromMapList(List<Map<String, dynamic>> list) {
    var objects = List<FileObject>();
    for (var map in list) {
      objects.add(FileObject.fromMap(map));
    }
    return objects;
  }
}

class FileObjectProvider {
  Database db;
  String path;

  FileObjectProvider(this.path);

  Future open() async {
    db = await openDatabase(path, version: 1, onCreate: (Database db, int version) async {
      await db.execute('''
        create table ${FileObject.tableFileObject} ( 
        ${FileObject.columnId} integer primary key autoincrement,
        ${FileObject.columnUrl} text,
        ${FileObject.columnName} text,
        ${FileObject.columnPath} text,
        ${FileObject.columnETag} text,
        ${FileObject.columnTimestamp} integer,
        ${FileObject.columnTouchedAt} integer
        )
      ''');
    });
  }

  Future<dynamic> updateOrInsert(FileObject fileObject) async {
    if (fileObject.id == null) {
      return await insert(fileObject);
    } else {
      return await update(fileObject);
    }
  }

  Future<FileObject> insert(FileObject fileObject) async {
    fileObject.touchedAt = DateTime.now();
    fileObject.timestamp ??= DateTime.now();
    fileObject.id = await db.insert(
      FileObject.tableFileObject,
      fileObject.toMap(),
    );
    return fileObject;
  }

  Future<int> update(FileObject fileObject) async {
    fileObject.touchedAt = DateTime.now();
    return await db.update(
      FileObject.tableFileObject,
      fileObject.toMap(),
      where: '${FileObject.columnId} = ?',
      whereArgs: [fileObject.id],
    );
  }

  Future<int> delete(int id) async {
    return await db.delete(
      FileObject.tableFileObject,
      where: '${FileObject.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<FileObject> get(String name) async {
    List<Map> maps = await db.query(
      FileObject.tableFileObject,
      columns: null,
      where: "${FileObject.columnName} = ?",
      whereArgs: [name],
    );
    if (maps.length > 0) {
      return FileObject.fromMap(maps.first);
    }
    return null;
  }

  Future deleteAll({Iterable<int> ids, Iterable<String> names}) async {
    if (ids != null && ids.isNotEmpty) {
      return await db.delete(
        FileObject.tableFileObject,
        where: "${FileObject.columnId} IN (" + ids.join(",") + ")",
      );
    }

    if (names != null && names.isNotEmpty) {
      return await db.delete(
        FileObject.tableFileObject,
        where: "${FileObject.columnName} IN (" + names.join(",") + ")",
      );
    }
  }

  Future<List<FileObject>> getAllObjects() async {
    List<Map> maps = await db.query(
      FileObject.tableFileObject,
      columns: null,
    );
    return FileObject.fromMapList(maps);
  }

  // Future<List<FileObject>> getOldObjects(Duration maxAge) async {
  //   List<Map> maps = await db.query(
  //     FileObject.tableFileObject,
  //     where: "${FileObject.columnTouchedAt} < ?",
  //     columns: null,
  //     whereArgs: [DateTime.now().subtract(maxAge).millisecondsSinceEpoch],
  //     limit: 100,
  //   );

  //   return FileObject.fromMapList(maps);
  // }

  Future close() async => await db.close();
}
