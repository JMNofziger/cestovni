/// Streaming ZIP sink used by the CES-41 assembler.
///
/// [add] is called once per small chunk (BOM, header, or a single CSV
/// row). A correct assembler never concatenates a whole table into one
/// [add]. Tests inject [CountingZipSink] / [MemoryZipSink]; production
/// uses the file-backed STORE writer.
library;

import 'dart:convert';
import 'dart:typed_data';

abstract class ZipSink {
  /// Begin a new entry. [name] is the path inside the ZIP (POSIX).
  void startFile(String name);

  /// Append [bytes] to the current entry. Must not retain [bytes]
  /// after return — callers may reuse the buffer.
  void add(List<int> bytes);

  void closeFile();

  void close();

  /// Best-effort close without a valid ZIP. [FileZipSink] uses this so
  /// a failed export can delete the `.tmp`. Default is a no-op.
  void abandon() {}

  /// Entry names in write order. The assembler runs this list through
  /// [excludePhotoPaths] as a last-line invariant.
  List<String> get fileNames;
}

/// Records every [add] so tests can prove the assembler streams.
class CountingZipSink implements ZipSink {
  final List<int> chunkSizes = <int>[];
  int addCalls = 0;
  int maxChunkBytes = 0;
  int totalBytes = 0;
  final List<String> _names = <String>[];
  bool _open = false;

  @override
  void startFile(String name) {
    if (_open) {
      throw StateError('closeFile before startFile($name)');
    }
    _open = true;
    _names.add(name);
  }

  @override
  void add(List<int> bytes) {
    if (!_open) throw StateError('add without startFile');
    addCalls++;
    chunkSizes.add(bytes.length);
    if (bytes.length > maxChunkBytes) maxChunkBytes = bytes.length;
    totalBytes += bytes.length;
  }

  @override
  void closeFile() {
    if (!_open) throw StateError('closeFile without startFile');
    _open = false;
  }

  @override
  void close() {
    if (_open) throw StateError('close with a file still open');
  }

  @override
  List<String> get fileNames => List<String>.unmodifiable(_names);
}

/// Concatenates each entry in memory for golden assertions.
class MemoryZipSink implements ZipSink {
  final Map<String, BytesBuilder> _files = <String, BytesBuilder>{};
  final List<String> _order = <String>[];
  String? _current;

  @override
  void startFile(String name) {
    if (_current != null) throw StateError('file already open');
    _current = name;
    _order.add(name);
    _files[name] = BytesBuilder(copy: false);
  }

  @override
  void add(List<int> bytes) {
    final name = _current;
    if (name == null) throw StateError('add without startFile');
    _files[name]!.add(bytes);
  }

  @override
  void closeFile() {
    if (_current == null) throw StateError('closeFile without startFile');
    _current = null;
  }

  @override
  void close() {
    if (_current != null) throw StateError('close with a file still open');
  }

  @override
  List<String> get fileNames => List<String>.unmodifiable(_order);

  Uint8List bytesOf(String name) {
    final builder = _files[name];
    if (builder == null) {
      throw StateError('no entry $name');
    }
    return Uint8List.fromList(builder.toBytes());
  }

  String utf8Of(String name) => utf8.decode(bytesOf(name));
}
