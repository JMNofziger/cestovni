/// STORE-method ZIP writer (no compression) that streams to a file.
///
/// Spec: `docs/specs/export-v1.md` assembly pipeline — row-by-row into
/// a ZIP backed by a temp file. Uses the data-descriptor bit so CRC
/// and sizes are written after each entry rather than buffering it.
///
/// `dart:io` bridge — keep out of the pure export files.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'crc32.dart';
import 'zip_sink.dart';

class FileZipSink implements ZipSink {
  FileZipSink(File file) : _raf = file.openSync(mode: FileMode.write);

  final RandomAccessFile _raf;
  final List<_Central> _central = <_Central>[];
  final List<String> _names = <String>[];
  bool _closed = false;

  String? _openName;
  int _openLocalOffset = 0;
  int _openSize = 0;
  int _openCrc = 0;
  DateTime _stamp = DateTime.now().toUtc();

  /// Override the DOS timestamp (tests).
  set stamp(DateTime utc) => _stamp = utc.toUtc();

  @override
  void startFile(String name) {
    if (_openName != null) throw StateError('file already open');
    _openName = name;
    _names.add(name);
    _openLocalOffset = _raf.positionSync();
    _openSize = 0;
    _openCrc = 0;
    _raf.writeFromSync(_localHeader(name, _stamp));
  }

  @override
  void add(List<int> bytes) {
    if (_openName == null) throw StateError('add without startFile');
    if (bytes.isEmpty) return;
    _openCrc = crc32Update(_openCrc, bytes);
    _openSize += bytes.length;
    _raf.writeFromSync(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  }

  @override
  void closeFile() {
    final name = _openName;
    if (name == null) throw StateError('closeFile without startFile');
    _raf.writeFromSync(_dataDescriptor(_openCrc, _openSize));
    _central.add(_Central(
      name: name,
      localOffset: _openLocalOffset,
      crc: _openCrc,
      size: _openSize,
      stamp: _stamp,
    ));
    _openName = null;
  }

  @override
  void close() {
    if (_closed) return;
    if (_openName != null) throw StateError('close with a file still open');
    final int cdStart = _raf.positionSync();
    for (final e in _central) {
      _raf.writeFromSync(_centralHeader(e));
    }
    final int cdSize = _raf.positionSync() - cdStart;
    _raf.writeFromSync(_eocd(
      entries: _central.length,
      cdSize: cdSize,
      cdOffset: cdStart,
    ));
    _raf.flushSync();
    _raf.closeSync();
    _closed = true;
  }

  @override
  void abandon() {
    if (_closed) return;
    _openName = null;
    try {
      _raf.closeSync();
    } catch (_) {}
    _closed = true;
  }

  @override
  List<String> get fileNames => List<String>.unmodifiable(_names);
}

class _Central {
  _Central({
    required this.name,
    required this.localOffset,
    required this.crc,
    required this.size,
    required this.stamp,
  });

  final String name;
  final int localOffset;
  final int crc;
  final int size;
  final DateTime stamp;
}

Uint8List _localHeader(String name, DateTime stamp) {
  final nameBytes = utf8.encode(name);
  final dos = _dosDateTime(stamp);
  final b = BytesBuilder(copy: false);
  _u32(b, 0x04034b50);
  _u16(b, 20); // version needed
  _u16(b, 0x0008); // data descriptor
  _u16(b, 0); // store
  _u16(b, dos.time);
  _u16(b, dos.date);
  _u32(b, 0); // crc placeholder
  _u32(b, 0);
  _u32(b, 0);
  _u16(b, nameBytes.length);
  _u16(b, 0);
  b.add(nameBytes);
  return b.takeBytes();
}

Uint8List _dataDescriptor(int crc, int size) {
  final b = BytesBuilder(copy: false);
  _u32(b, 0x08074b50);
  _u32(b, crc);
  _u32(b, size);
  _u32(b, size);
  return b.takeBytes();
}

Uint8List _centralHeader(_Central e) {
  final nameBytes = utf8.encode(e.name);
  final dos = _dosDateTime(e.stamp);
  final b = BytesBuilder(copy: false);
  _u32(b, 0x02014b50);
  _u16(b, 20);
  _u16(b, 20);
  _u16(b, 0x0008);
  _u16(b, 0);
  _u16(b, dos.time);
  _u16(b, dos.date);
  _u32(b, e.crc);
  _u32(b, e.size);
  _u32(b, e.size);
  _u16(b, nameBytes.length);
  _u16(b, 0);
  _u16(b, 0);
  _u16(b, 0);
  _u16(b, 0);
  _u32(b, 0);
  _u32(b, e.localOffset);
  b.add(nameBytes);
  return b.takeBytes();
}

Uint8List _eocd({
  required int entries,
  required int cdSize,
  required int cdOffset,
}) {
  final b = BytesBuilder(copy: false);
  _u32(b, 0x06054b50);
  _u16(b, 0);
  _u16(b, 0);
  _u16(b, entries);
  _u16(b, entries);
  _u32(b, cdSize);
  _u32(b, cdOffset);
  _u16(b, 0);
  return b.takeBytes();
}

void _u16(BytesBuilder b, int v) {
  b.addByte(v & 0xFF);
  b.addByte((v >> 8) & 0xFF);
}

void _u32(BytesBuilder b, int v) {
  b.addByte(v & 0xFF);
  b.addByte((v >> 8) & 0xFF);
  b.addByte((v >> 16) & 0xFF);
  b.addByte((v >> 24) & 0xFF);
}

({int time, int date}) _dosDateTime(DateTime utc) {
  final dt = utc.toUtc();
  final time = (dt.second ~/ 2) | (dt.minute << 5) | (dt.hour << 11);
  final date = dt.day | (dt.month << 5) | ((dt.year - 1980) << 9);
  return (time: time, date: date);
}
