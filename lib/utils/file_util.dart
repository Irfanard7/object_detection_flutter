import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// File I/O utilities.
class FileUtil {

  /// Loads a label file into a list of strings
  ///
  /// A legal label file is the plain text file whose contents are split into lines, and each line
  /// is an individual value. The empty lines will be ignored. The file should be in assets of the
  /// context.
  ///
  /// [fileAssetLocation] specifies the path of asset at project level.
  /// For example: If file is located at <root-dir>/assets/filename.txt then fileAssetLocation is
  /// assets/filename.txt.
  static Future<List<String>> loadLabels(String fileAssetLocation) async {
    final fileString = await rootBundle.loadString('$fileAssetLocation');
    return labelListFromString(fileString);
  }

  /// Splits the string at matches of newline character and returns a list of substrings.
  static List<String> labelListFromString(String fileString) {
    var list = <String>[];
    final newLineList = fileString.split('\n');
    for (var i = 0; i < newLineList.length; i++) {
      var entry = newLineList[i].trim();
      if (entry.length > 0) {
        list.add(entry);
      }
    }
    return list;
  }
}