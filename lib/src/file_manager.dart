import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_network_file_manager/src/file_fetcher.dart';
import 'package:flutter_network_file_manager/src/file_info.dart';
import 'package:flutter_network_file_manager/src/file_object.dart';
import 'package:flutter_network_file_manager/src/file_store.dart';
import 'package:flutter_network_file_manager/src/web_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

class DefaultFileManager extends BaseFileManager {
  static const key = "libSavedFileData";

  static DefaultFileManager _instance;

  /// The DefaultFileManager that can be easily used directly. The code of
  /// this implementation can be used as inspiration for more complex file
  /// managers.
  factory DefaultFileManager() {
    if (_instance == null) {
      _instance = DefaultFileManager._();
    }
    return _instance;
  }

  DefaultFileManager._() : super(key);

  Future<String> getFilePath() async {
    var directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, key);
  }
}

abstract class BaseFileManager {
  Future<String> _fileBasePath;

  final String _storeKey;

  /// This path is used as base folder for all saved files.
  Future<String> getFilePath();

  /// Store helper for saved files
  FileStore store;

  /// Webhelper to download and store files
  WebHelper webHelper;

  BaseFileManager(
    this._storeKey, {
    FileFetcher fileFetcher,
  }) {
    _fileBasePath = getFilePath();
    store = FileStore(_fileBasePath, _storeKey);
    webHelper = WebHelper(store, fileFetcher);
  }

  Future<File> getSingleFile({
    String name,
    String url,
    DateTime timestamp,
    Map<String, String> headers,
  }) async {
    if (name == null) {
      name = url;
    }

    var storageFile = await getFileFromStorage(name);
    if (storageFile != null) {
      if ((timestamp != null && storageFile.timestamp.isBefore(timestamp)) || storageFile.originalUrl != url) {
        webHelper.downloadFile(
          name: name,
          url: url,
          timestamp: timestamp,
          authHeaders: headers,
        );
      }
      return storageFile.file;
    }

    try {
      var download = await webHelper.downloadFile(
        name: name,
        url: url,
        timestamp: timestamp,
        authHeaders: headers,
      );
      return download.file;
    } catch (e) {
      return null;
    }
  }

  Stream<FileInfo> getFile({
    String name,
    String url,
    DateTime timestamp,
    bool force = false,
    Map<String, String> headers,
  }) async* {
    if (name == null) {
      name = url;
    }

    FileInfo storageFile = await getFileFromStorage(name);
    if (storageFile != null) {
      yield storageFile;
    }
    if (storageFile == null ||
        (timestamp != null && storageFile.timestamp.isBefore(timestamp)) ||
        storageFile.originalUrl != url) {
      try {
        FileInfo webFile = await webHelper.downloadFile(
          name: name,
          url: url,
          timestamp: timestamp,
          authHeaders: headers,
        );
        if (webFile != null) {
          yield webFile;
        }
      } catch (e) {
        if (storageFile == null) {
          throw e;
        }
      }
    }
  }

  ///Download the file and add to storage
  Future<FileInfo> downloadFile({
    @required String name,
    @required String url,
    Map<String, String> authHeaders,
    bool force = false,
  }) async {
    return await webHelper.downloadFile(
      name: name,
      url: url,
      authHeaders: authHeaders,
      ignoreMemCache: force,
    );
  }

  ///Get the file from the storage
  Future<FileInfo> getFileFromStorage(String name) async {
    return await store.getFile(name);
  }

  Future<File> putFile(String name, String url, Uint8List fileBytes,
      {String eTag, Duration maxAge = const Duration(days: 30), String fileExtension = "file"}) async {
    var fileObject = await store.retrieveFileData(name);
    if (fileObject == null) {
      var relativePath = "${Uuid().v1()}.$fileExtension";
      fileObject = FileObject(
        name: name,
        url: url,
        relativePath: relativePath,
      );
    }

    fileObject.eTag = eTag;

    var path = p.join(await getFilePath(), fileObject.relativePath);
    var folder = File(path).parent;
    if (!(await folder.exists())) {
      folder.createSync(recursive: true);
    }
    var file = await File(path).writeAsBytes(fileBytes);

    store.putFile(fileObject);

    return file;
  }

  /// Delete a file from the storage
  deleteFile(String name) async {
    var fileObject = await store.retrieveFileData(name);
    if (fileObject != null) {
      await store.deleteSavedFile(fileObject);
    }
  }

  /// Deletes all files from the storage
  deleteAll() async {
    await store.deleteAll();
  }
}
