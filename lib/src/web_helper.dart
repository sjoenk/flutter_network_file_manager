import 'dart:async';
import 'dart:io';

import 'package:flutter_network_file_manager/src/file_object.dart';
import 'package:flutter_network_file_manager/src/file_store.dart';
import 'package:flutter_network_file_manager/src/file_fetcher.dart';
import 'package:flutter_network_file_manager/src/file_info.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:meta/meta.dart';

class WebHelper {
  FileStore _store;
  FileFetcher _fileFetcher;
  Map<String, Future<FileInfo>> _memCache;

  WebHelper(this._store, this._fileFetcher) {
    _memCache = Map();
    if (_fileFetcher == null) {
      _fileFetcher = _defaultHttpGetter;
    }
  }

  ///Download the file from the url
  Future<FileInfo> downloadFile({
    @required String name,
    @required String url,
    DateTime timestamp,
    Map<String, String> authHeaders,
    bool ignoreMemCache = false,
  }) async {
    timestamp = timestamp ?? DateTime.now();
    if (!_memCache.containsKey(name) || ignoreMemCache) {
      var completer = Completer<FileInfo>();
      _downloadRemoteFile(
        url: url,
        name: name,
        timestamp: timestamp,
        authHeaders: authHeaders,
      ).then((fileObject) {
        completer.complete(fileObject);
      }).catchError((e) {
        completer.completeError(e);
      }).whenComplete(() {
        _memCache.remove(name);
      });

      _memCache[name] = completer.future;
    }
    return _memCache[name];
  }

  ///Download the file from the url
  Future<FileInfo> _downloadRemoteFile({
    @required String url,
    @required String name,
    DateTime timestamp,
    Map<String, String> authHeaders,
  }) async {
    return Future.sync(() async {
      var fileObject = await _store.retrieveFileData(name);
      if (fileObject == null) {
        fileObject = FileObject(
          name: name,
          url: url,
          timestamp: timestamp,
        );
      } else {
        fileObject.url = url;
        fileObject.timestamp = timestamp;
      }

      var headers = Map<String, String>();
      if (authHeaders != null) {
        headers.addAll(authHeaders);
      }

      if (fileObject.eTag != null) {
        headers[HttpHeaders.ifNoneMatchHeader] = fileObject.eTag;
      }

      var success = false;

      var response = await _fileFetcher(url, headers: headers);
      success = await _handleHttpResponse(response, fileObject);

      if (!success) {
        throw HttpException(
            "No valid statuscode. Statuscode was ${response?.statusCode}");
      }

      _store.putFile(fileObject);
      var filePath = p.join(await _store.filePath, fileObject.relativePath);

      return FileInfo(
        name: name,
        originalUrl: url,
        file: File(filePath),
        source: FileSource.Online,
        touchedAt: fileObject.touchedAt,
        timestamp: fileObject.timestamp,
      );
    });
  }

  Future<FileFetcherResponse> _defaultHttpGetter(String url,
      {Map<String, String> headers}) async {
    var httpResponse = await http.get(url, headers: headers);
    return HttpFileFetcherResponse(httpResponse);
  }

  Future<bool> _handleHttpResponse(
    FileFetcherResponse response,
    FileObject fileObject,
  ) async {
    if (response.statusCode == 200) {
      var basePath = await _store.filePath;
      _setDataFromHeaders(fileObject, response);
      var path = p.join(basePath, fileObject.relativePath);

      var folder = File(path).parent;
      if (!(await folder.exists())) {
        folder.createSync(recursive: true);
      }
      await File(path).writeAsBytes(response.bodyBytes);
      return true;
    }
    if (response.statusCode == 304) {
      await _setDataFromHeaders(fileObject, response);
      return true;
    }
    return false;
  }

  _setDataFromHeaders(
    FileObject fileObject,
    FileFetcherResponse response,
  ) async {
    //Without a cache-control header we keep the file for a week
    var ageDuration = Duration(days: 7);

    if (response.hasHeader(HttpHeaders.cacheControlHeader)) {
      var cacheControl = response.header(HttpHeaders.cacheControlHeader);
      var controlSettings = cacheControl.split(", ");

      controlSettings.forEach((setting) {
        if (setting.startsWith("max-age=")) {
          var validSeconds = int.tryParse(setting.split("=")[1]) ?? 0;

          if (validSeconds > 0) {
            ageDuration = Duration(seconds: validSeconds);
          }
        }
      });
    }

    fileObject.touchedAt = DateTime.now().add(ageDuration);

    if (response.hasHeader(HttpHeaders.etagHeader)) {
      fileObject.eTag = response.header(HttpHeaders.etagHeader);
    }

    var fileExtension = "";

    if (response.hasHeader(HttpHeaders.contentTypeHeader)) {
      var type = response.header(HttpHeaders.contentTypeHeader).split("/");
      if (type.length == 2) {
        fileExtension = ".${type[1]}";
      }
    }

    var oldPath = fileObject.relativePath;
    if (oldPath != null && !oldPath.endsWith(fileExtension)) {
      _removeOldFile(oldPath);
      fileObject.relativePath = null;
    }

    if (fileObject.relativePath == null) {
      fileObject.relativePath = "${Uuid().v1()}$fileExtension";
    }
  }

  _removeOldFile(String relativePath) async {
    var path = p.join(await _store.filePath, relativePath);
    var file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
