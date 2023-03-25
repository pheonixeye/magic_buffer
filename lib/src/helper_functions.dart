import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:magic_buffer/magic_buffer.dart';
import 'package:magic_buffer/src/constants.dart';
import 'package:magic_buffer/src/errors.dart';

///
/// Need to make sure that buffer isn't trying to write out of bounds.
///
void checkOffset(int offset, int ext, int length) {
  if ((offset % 1) != 0 || offset < 0) {
    throw RangeError('offset is not uint');
  }
  if (offset + ext > length) {
    throw RangeError('Trying to access beyond buffer length');
  }
}

void assertSize(dynamic size) {
  if (size is! int) {
    throw InvalidTypeError('"size" argument must be of type int');
  } else if (size < 0) {
    throw RangeError('The value " $size " is invalid for option "size"');
  }
}

int checked(int length) {
  // Note: cannot use 'length < K_MAX_LENGTH' here because that fails when
  // length is NaN (which is otherwise coerced to zero.)
  if (length >= K_MAX_LENGTH) {
    throw RangeError(
        'Attempt to allocate Buffer larger than maximum size: 0x${K_MAX_LENGTH.toRadixString(16)} bytes');
  }
  return length | 0;
}

//*Write Methods
//? tested - failed
int hexWrite(Buffer buf, String string, [int offset = 0, int length = 0]) {
  final remaining = buf.length - offset;
  if (length == 0) {
    length = remaining;
  } else {
    if (length > remaining) {
      length = remaining;
    }
  }

  final strLen = string.length;

  if (length > strLen ~/ 2) {
    length = strLen ~/ 2;
  }
  int i;
  for (i = 0; i < length; ++i) {
    final parsed = int.tryParse(string.substring(i * 2, 2), radix: 16);
    if (parsed == null) {
      return i;
    }
    buf[offset + i] = parsed;
  }
  return i;
}

int blitBuffer(Buffer src, Buffer dst, int offset, int length) {
  int i;
  for (i = 0; i < length; ++i) {
    if ((i + offset >= dst.length) || (i >= src.length)) break;
    dst[i + offset] = src[i];
  }
  return i;
}

List<int> utf8ToBytes(String string, {int? units}) {
  return utf8.encode(string);
}

List<int> asciiToBytes(String string) {
  return ascii.encode(string);
}

List<int> utf16leToBytes(String str, int units) {
  int c, hi, lo;
  List<int> byteArray = [];
  for (int i = 0; i < str.length; ++i) {
    if ((units -= 2) < 0) break;

    c = str.runes.elementAt(i);
    hi = c >> 8;
    lo = c % 256;
    byteArray.add(lo);
    byteArray.add(hi);
  }

  return byteArray;
}

List<int> base64ToBytes(String string) {
  return base64.decode(base64.normalize(string));
}

int utf8Write(Buffer buf, String string, int offset, int length) {
  return blitBuffer(Buffer(utf8ToBytes(string, units: buf.length - offset)),
      buf, offset, length);
}

int asciiWrite(Buffer buf, String string, int offset, int length) {
  return blitBuffer(Buffer(asciiToBytes(string)), buf, offset, length);
}

int base64Write(Buffer buf, String string, int offset, int length) {
  return blitBuffer(Buffer(base64ToBytes(string)), buf, offset, length);
}

int ucs2Write(Buffer buf, String string, int offset, int length) {
  return blitBuffer(
      Buffer(utf16leToBytes(string, buf.length - offset)), buf, offset, length);
}

String utf8Slice(Buffer buf, int start, int end) {
  end = min(buf.length, end);
  List<int> res = [];

  int i = start;
  while (i < end) {
    final firstByte = buf[i];
    dynamic codePoint;
    var bytesPerSequence = (firstByte > 0xEF)
        ? 4
        : (firstByte > 0xDF)
            ? 3
            : (firstByte > 0xBF)
                ? 2
                : 1;

    if (i + bytesPerSequence <= end) {
      int secondByte, thirdByte, fourthByte, tempCodePoint;

      switch (bytesPerSequence) {
        case 1:
          if (firstByte < 0x80) {
            codePoint = firstByte;
          }
          break;
        case 2:
          secondByte = buf[i + 1];
          if ((secondByte & 0xC0) == 0x80) {
            tempCodePoint = (firstByte & 0x1F) << 0x6 | (secondByte & 0x3F);
            if (tempCodePoint > 0x7F) {
              codePoint = tempCodePoint;
            }
          }
          break;
        case 3:
          secondByte = buf[i + 1];
          thirdByte = buf[i + 2];
          if ((secondByte & 0xC0) == 0x80 && (thirdByte & 0xC0) == 0x80) {
            tempCodePoint = (firstByte & 0xF) << 0xC |
                (secondByte & 0x3F) << 0x6 |
                (thirdByte & 0x3F);
            if (tempCodePoint > 0x7FF &&
                (tempCodePoint < 0xD800 || tempCodePoint > 0xDFFF)) {
              codePoint = tempCodePoint;
            }
          }
          break;
        case 4:
          secondByte = buf[i + 1];
          thirdByte = buf[i + 2];
          fourthByte = buf[i + 3];
          if ((secondByte & 0xC0) == 0x80 &&
              (thirdByte & 0xC0) == 0x80 &&
              (fourthByte & 0xC0) == 0x80) {
            tempCodePoint = (firstByte & 0xF) << 0x12 |
                (secondByte & 0x3F) << 0xC |
                (thirdByte & 0x3F) << 0x6 |
                (fourthByte & 0x3F);
            if (tempCodePoint > 0xFFFF && tempCodePoint < 0x110000) {
              codePoint = tempCodePoint;
            }
          }
      }
    }

    if (codePoint == null) {
      // we did not generate a valid codePoint so insert a
      // replacement char (U+FFFD) and advance only 1 byte
      codePoint = 0xFFFD;
      bytesPerSequence = 1;
    } else if (codePoint > 0xFFFF) {
      // encode to utf16 (surrogate pair dance)
      codePoint -= 0x10000;
      res.add(codePoint >>> 10 & 0x3FF | 0xD800);
      codePoint = 0xDC00 | codePoint & 0x3FF;
    }

    res.add(codePoint);
    i += bytesPerSequence;
  }

  return decodeCodePointsArray(res);
}

String decodeCodePointsArray(List<int> codePoints) {
  final len = codePoints.length;
  if (len <= MAX_ARGUMENTS_LENGTH) {
    return String.fromCharCodes(codePoints); // avoid extra slice()
  }

  // Decode in chunks to avoid "call stack size exceeded".
  String res = '';
  int i = 0;
  while (i < len) {
    res +=
        String.fromCharCodes(codePoints.sublist(i, i += MAX_ARGUMENTS_LENGTH));
  }
  return res;
}

String base64Slice(Buffer buf, int start, int end) {
  if (start == 0 && end == buf.length) {
    return base64.encode(buf.buffer);
  } else {
    return base64.encode(buf.slice(start, end).buffer);
  }
}

String asciiSlice(Buffer buf, int start, int end) {
  String ret = '';
  end = min(buf.length, end);

  for (int i = start; i < end; ++i) {
    ret += String.fromCharCode(buf[i] & 0x7F);
  }
  return ret;
}

String latin1Slice(Buffer buf, int start, int end) {
  String ret = '';
  end = min(buf.length, end);

  for (int i = start; i < end; ++i) {
    ret += String.fromCharCode(buf[i]);
  }
  return ret;
}

//? tested - failed
String hexSlice(Buffer buf, int start, int end) {
  final len = buf.length;

  if (start < 0) start = 0;
  if (end < 0 || end > len) end = len;

  String out = '';
  for (int i = start; i < end; ++i) {
    out += hexSliceLookupTable()[buf[i]];
  }
  return out;
}

//? tested - passed
String utf16leSlice(Buffer buf, int start, int end) {
  final bytes = buf.slice(start, end);
  String res = '';
  // If bytes.length is odd, the last 8 bits must be ignored (same as node.js)
  for (int i = 0; i < bytes.length - 1; i += 2) {
    res += String.fromCharCode(bytes[i] + (bytes[i + 1] * 256));
  }
  return res;
}

List<String> hexSliceLookupTable() {
  const alphabet = '0123456789abcdef';
  List<String> table = List.filled(256, '');
  // table.length = 256;
  for (int i = 0; i < 16; ++i) {
    final i16 = i * 16;
    for (int j = 0; j < 16; ++j) {
      table[i16 + j] = alphabet[i] + alphabet[j];
    }
  }
  return table;
}

//* index functions

// Finds either the first index of 'val' in 'buffer' at offset >= 'byteOffset',
// OR the last index of 'val' in 'buffer' at offset <= 'byteOffset'.
//
// Arguments:
// - buffer - a Buffer to search
// - val - a string, Buffer, or number
// - byteOffset - an index into 'buffer'; will be clamped to an int32
// - encoding - an optional encoding, relevant is val is a string
// - dir - true for indexOf, false for lastIndexOf
int bidirectionalIndexOf(
    Buffer buffer, dynamic val, int byteOffset, String encoding, bool dir) {
  // Empty buffer means no match
  if (buffer.length == 0) return -1;

  // Normalize byteOffset
  if (byteOffset > 0x7fffffff) {
    byteOffset = 0x7fffffff;
  } else if (byteOffset < -0x80000000) {
    byteOffset = -0x80000000;
  }
  byteOffset = byteOffset.abs(); // Coerce to Number.
  if (byteOffset.isNaN) {
    // byteOffset: it it's undefined, null, NaN, "foo", etc, search whole buffer
    byteOffset = dir ? 0 : (buffer.length - 1);
  }

  // Normalize byteOffset: negative offsets start from the end of the buffer
  if (byteOffset < 0) byteOffset = buffer.length + byteOffset;
  if (byteOffset >= buffer.length) {
    if (dir) {
      return -1;
    } else {
      byteOffset = buffer.length - 1;
    }
  } else if (byteOffset < 0) {
    if (dir) {
      byteOffset = 0;
    } else {
      return -1;
    }
  }

  // Normalize val
  if (val is String) {
    val = Buffer.from(val, 0, 0, encoding);
  }

  // Finally, search either indexOf (if dir is true) or lastIndexOf
  if (Buffer.isBuffer(val)) {
    // Special case: looking for empty string/buffer always fails
    if (val.length == 0) {
      return -1;
    }
    return arrayIndexOf(buffer, val, byteOffset, encoding, dir);
  } else if (val is int) {
    val = val & 0xFF; // Search for a byte value [0-255]
    if (dir) {
      return buffer.indexOf(val, byteOffset);
    } else {
      return buffer.lastIndexOf(val, byteOffset);
    }
  }
  try {
    return arrayIndexOf(buffer, [val], byteOffset, encoding, dir);
  } catch (e) {
    throw InvalidTypeError('val must be string, number or Buffer');
  }
}

int arrayIndexOf(
    Buffer arr, dynamic val, int byteOffset, String? encoding, bool dir) {
  int indexSize = 1;
  int arrLength = arr.length;
  int valLength = val.length;

  if (encoding != null) {
    encoding = encoding.toLowerCase();
    if (encoding == 'ucs2' ||
        encoding == 'ucs-2' ||
        encoding == 'utf16le' ||
        encoding == 'utf-16le') {
      if (arr.length < 2 || val.length < 2) {
        return -1;
      }
      indexSize = 2;
      arrLength ~/= 2;
      valLength ~/= 2;
      byteOffset ~/= 2;
    }
  }

  int read(Buffer buf, int i) {
    if (indexSize == 1) {
      return buf[i];
    } else {
      return buf.readUInt16BE(i * indexSize);
    }
  }

  int i;
  if (dir) {
    int foundIndex = -1;
    for (i = byteOffset; i < arrLength; i++) {
      if (read(arr, i) == read(val, foundIndex == -1 ? 0 : i - foundIndex)) {
        if (foundIndex == -1) foundIndex = i;
        if (i - foundIndex + 1 == valLength) return foundIndex * indexSize;
      } else {
        if (foundIndex != -1) i -= i - foundIndex;
        foundIndex = -1;
      }
    }
  } else {
    if (byteOffset + valLength > arrLength) byteOffset = arrLength - valLength;
    for (i = byteOffset; i >= 0; i--) {
      bool found = true;
      for (int j = 0; j < valLength; j++) {
        if (read(arr, i + j) != read(val, j)) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
  }

  return -1;
}

//* from array methods
//from Uint8List
Buffer fromArrayBuffer(Uint8List array, [int byteOffset = 0, int length = 0]) {
  if (byteOffset < 0 || array.lengthInBytes < byteOffset) {
    throw RangeError('"offset" is outside of buffer bounds');
  }

  if (array.lengthInBytes < byteOffset + length) {
    throw RangeError('"length" is outside of buffer bounds');
  }

  Buffer buf;
  if (byteOffset == 0 && length == 0) {
    buf = Buffer(array);
  } else if (length == 0) {
    final l = Uint8List(array.length);
    l.setAll(byteOffset, array);
    buf = Buffer(l);
  } else {
    final l = Uint8List(length);
    l.setAll(byteOffset, array);
    buf = Buffer(l);
  }
  return buf;
}

//from List<int>
Buffer fromArrayLike(List<int> array) {
  final length = array.isEmpty ? 0 : checked(array.length) | 0;
  final buf = createBuffer(length);
  for (int i = 0; i < length; i += 1) {
    buf[i] = array[i] & 255;
  }
  return buf;
}

//from arrayview ?? Uint8List View??
// Buffer fromArrayView(List<int> arrayView) {
//   if (arrayView is Uint8List) {
//     final copy = Buffer(Uint8List.sublistView(arrayView));
//     return fromArrayBuffer(copy.buffer, copy.offset, copy.length);
//   }
//   return fromArrayLike(arrayView);
// }

//check functions
void checkInt(Buffer buf, int value, int offset, int ext, int max, int min) {
  if (!Buffer.isBuffer(buf)) {
    throw InvalidTypeError('"buffer" argument must be a Buffer instance');
  }
  if (value > max || value < min) {
    throw RangeError('"value" argument is out of bounds');
  }
  if (offset + ext > buf.length) {
    throw RangeError('Index out of range');
  }
}

void checkIntBI(value, min, max, buf, offset, byteLength) {
  if (value > max || value < min) {
    final n = min is BigInt ? 'n' : '';
    String range;
    if (byteLength > 3) {
      if (min == 0 || min == BigInt.from(0)) {
        range = '>= 0$n and < 2$n ** ${(byteLength + 1) * 8}$n';
      } else {
        range = '>= -(2$n ** ${(byteLength + 1) * 8 - 1}$n) and < 2 ** '
            '${(byteLength + 1) * 8 - 1}$n';
      }
    } else {
      range = '>= $min$n and <= $max$n';
    }
    throw RangeError.value(value, 'value', range);
  }
  checkBounds(buf, offset, byteLength);
}

void checkBounds(buf, offset, byteLength) {
  validateNumber(offset, 'offset');
  if (buf[offset] == null || buf[offset + byteLength] == null) {
    boundsError(offset, buf.length - (byteLength + 1));
  }
}

void validateNumber(dynamic value, String? name) {
  if (value is! int) {
    throw InvalidTypeError('$name, $value');
  }
}

void boundsError(dynamic value, int length, [String? type]) {
  if ((value).floor() != value) {
    validateNumber(value, type);
    throw InvalidTypeError("$type || 'offset', 'an integer', $value");
  }

  if (length < 0) {
    throw RangeError('');
  }

  throw RangeError(
      "type || 'offset',`>= ${type != null ? 1 : 0} and <= $length`, value");
}
