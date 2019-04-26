import 'dart:async';
import 'dart:io';

import 'package:flutter_network_file_manager/src/file_object.dart';
import 'package:flutter_network_file_manager/src/file_info.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

class FileStore {
  Map<String, Future<FileObject>> _memCache = Map();

  int _nrOfDbConnections = 0;
  Future<String> filePath;
  Future<FileObjectProvider> _fileObjectProvider;
  String storeKey;

  FileStore(
    Future<String> basePath,
    this.storeKey,
  ) {
    filePath = basePath;
    _fileObjectProvider = _getObjectProvider();
  }

  Future<FileObjectProvider> _getObjectProvider() async {
    String databasesPath = await getDatabasesPath();
    String path = p.join(databasesPath, "$storeKey.db");

    // Make sure the directory exists
    try {
      await Directory(databasesPath).create(recursive: true);
    } catch (_) {}
    return FileObjectProvider(path);
  }

  Future<FileInfo> getFile(String name) async {
    FileObject fileObject = await retrieveFileData(name);
    if (fileObject == null || fileObject.relativePath == null) {
      return null;
    }
    String path = p.join(await filePath, fileObject.relativePath);
    return FileInfo(
      name: name,
      originalUrl: fileObject.url,
      file: File(path),
      source: FileSource.Storage,
      touchedAt: fileObject.touchedAt,
      timestamp: fileObject.timestamp,
    );
  }

  putFile(FileObject fileObject) async {
    _memCache[fileObject.name] = Future<FileObject>.value(fileObject);
    _updateFileDataInDatabase(fileObject);
  }

  Future<FileObject> retrieveFileData(String name) {
    if (!_memCache.containsKey(name)) {
      Completer completer = Completer<FileObject>();
      _getFileDataFromDatabase(name).then((fileObject) async {
        if (fileObject != null && !await _fileExists(fileObject)) {
          fileObject = FileObject(
            name: name,
            id: fileObject.id,
          );
        }
        completer.complete(fileObject);
      });

      _memCache[name] = completer.future;
    }
    return _memCache[name];
  }

  Future<bool> _fileExists(FileObject fileObject) async {
    if (fileObject?.relativePath == null) {
      return false;
    }
    return File(p.join(
      await filePath,
      fileObject.relativePath,
    )).exists();
  }

  Future<FileObject> _getFileDataFromDatabase(String name) async {
    FileObjectProvider provider = await _openDatabaseConnection();
    FileObject data = await provider.get(name);

    if (await _fileExists(data)) {
      _updateFileDataInDatabase(data);
    }
    _closeDatabaseConnection();
    return data;
  }

  Lock databaseConnectionLock = Lock();

  Future<FileObjectProvider> _openDatabaseConnection() async {
    FileObjectProvider provider = await _fileObjectProvider;
    if (_nrOfDbConnections == 0) {
      await databaseConnectionLock.synchronized(() async {
        if (_nrOfDbConnections == 0) {
          await provider.open();
        }
        _nrOfDbConnections++;
      });
    } else {
      _nrOfDbConnections++;
    }
    return provider;
  }

  Future<dynamic> _updateFileDataInDatabase(FileObject fileObject) async {
    FileObjectProvider provider = await _openDatabaseConnection();
    var data = await provider.updateOrInsert(fileObject);
    _closeDatabaseConnection();
    return data;
  }

  _closeDatabaseConnection() async {
    if (_nrOfDbConnections == 1) {
      await databaseConnectionLock.synchronized(() {
        _nrOfDbConnections--;
        if (_nrOfDbConnections == 0) {
          _cleanAndClose();
        }
      });
    } else {
      _nrOfDbConnections--;
    }
  }

  _cleanAndClose() async {
    _nrOfDbConnections++;
    FileObjectProvider provider = await _fileObjectProvider;
    // var overCapacity = await provider.getObjectsOverCapacity(_capacity);
    // List<FileObject> oldObjects = await provider.getOldObjects(_maxAge);

    List<int> toRemove = List<int>();
    // overCapacity.forEach((fileObject) async {
    //   _removeSavedFile(fileObject, toRemove);
    // });
    // oldObjects.forEach((fileObject) async {
    //   _removeSavedFile(fileObject, toRemove);
    // });

    await provider.deleteAll(ids: toRemove);
    await databaseConnectionLock.synchronized(() async {
      _nrOfDbConnections--;
      if (_nrOfDbConnections == 0) {
        await provider.close();
      }
    });
  }

  deleteAll() async {
    var provider = await _openDatabaseConnection();
    var toRemove = List<int>();

    var allObjects = await provider.getAllObjects();

    allObjects.forEach((fileObject) async {
      _deleteSavedFile(fileObject, toRemove);
    });

    await provider.deleteAll(ids: toRemove);
    _closeDatabaseConnection();
  }

  deleteSavedFile(FileObject fileObject) async {
    var provider = await _openDatabaseConnection();
    var toRemove = List<int>();
    _deleteSavedFile(fileObject, toRemove);
    await provider.deleteAll(ids: toRemove);
    _closeDatabaseConnection();
  }

  _deleteSavedFile(FileObject fileObject, List<int> toRemove) async {
    if (!toRemove.contains(fileObject.id)) {
      toRemove.add(fileObject.id);
    }
    if (_memCache.containsKey(fileObject.name)) {
      _memCache.remove(fileObject.name);
    }
    var file = File(p.join(await filePath, fileObject.relativePath));
    if (await file.exists()) {
      file.delete();
    }
  }
}
