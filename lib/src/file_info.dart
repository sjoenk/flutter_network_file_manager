import 'dart:io';

import 'package:meta/meta.dart';

enum FileSource { NA, Storage, Online }

class FileInfo {
  final File file;
  final String name;
  final String originalUrl;
  final FileSource source;
  final DateTime touchedAt;
  final DateTime timestamp;

  FileInfo({
    @required this.name,
    @required this.file,
    this.source = FileSource.NA,
    this.touchedAt,
    this.timestamp,
    this.originalUrl,
  });
}
