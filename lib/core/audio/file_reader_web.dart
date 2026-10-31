import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'file_reader_stub.dart';

export 'file_reader_stub.dart';

class WebFileBytesReader implements FileBytesReader {
  @override
  Future<Uint8List> readBytes(String path) async {
    // On web, path is a blob: URL
    final response = await http.get(Uri.parse(path));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to read blob url on web: ${response.statusCode}');
  }
}

FileBytesReader getFileBytesReader() => WebFileBytesReader();
