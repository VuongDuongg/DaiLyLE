import 'dart:typed_data';

abstract class FileBytesReader {
  Future<Uint8List> readBytes(String path);
}

FileBytesReader getFileBytesReader() =>
    throw UnsupportedError('Cannot create a FileBytesReader without platform implementation');

