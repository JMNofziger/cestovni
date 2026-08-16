/// IEEE CRC-32 (ZIP / PNG polynomial 0xEDB88320).
///
/// Used by the STORE zip writer so we do not pull `package:archive`
/// into the production write path.
library;

int crc32Update(int crc, List<int> bytes) {
  var c = (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b & 0xFF;
    for (var i = 0; i < 8; i++) {
      c = (c & 1) == 1 ? ((c >> 1) ^ 0xEDB88320) : (c >> 1);
      c &= 0xFFFFFFFF;
    }
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

int crc32(List<int> bytes) => crc32Update(0, bytes);
