import 'dart:io';
import 'dart:typed_data';
import 'file_reader_stub.dart';

export 'file_reader_stub.dart';

class IoFileBytesReader implements FileBytesReader {
  @override
  Future<Uint8List> readBytes(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }
}

FileBytesReader getFileBytesReader() => IoFileBytesReader();
