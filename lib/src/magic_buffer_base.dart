import 'dart:math';
import 'dart:typed_data';

import 'package:ieee754_dart/ieee754_dart.dart';
import 'package:magic_buffer/src/annotations.dart';
import 'package:magic_buffer/src/errors.dart';
import 'package:magic_buffer/src/helper_functions.dart';

import 'constants.dart';

Buffer createBuffer(int length) {
  if (length > K_MAX_LENGTH) {
    throw RangeError('The value $length is invalid for option "size"');
  }
  // Return an augmented `Uint8Array` instance
  // ignore: no_leading_underscores_for_local_identifiers
  Uint8List _buf = Uint8List(length);
  return Buffer(_buf);
}

int byteLength(dynamic value,
    [String encoding = 'utf8', bool mustMatch = true]) {
  if (value is String) {
    return value.length;
  }
  if (value is Uint8List) {
    return value.lengthInBytes;
  }
  if (value is Buffer) {
    return value._buf.lengthInBytes;
  }
  if (value is! String) {
    throw InvalidTypeError(
        'The "value" argument must be one of type String, Buffer, or Uint8List. '
        'Received type ${value.runtimeTypes}');
  }

  final len = value.length;
  if (!mustMatch && len == 0) return 0;

  // Use a for loop to avoid recursion
  bool loweredCase = false;
  for (;;) {
    switch (encoding) {
      case 'ascii':
      case 'latin1':
      case 'binary':
        return len;
      case 'utf8':
      case 'utf-8':
        return utf8ToBytes(value).length;
      case 'ucs2':
      case 'ucs-2':
      case 'utf16le':
      case 'utf-16le':
        return len * 2;
      case 'hex':
        return len >>> 1;
      case 'base64':
        return base64ToBytes(value).length;
      default:
        if (loweredCase) {
          return mustMatch ? -1 : utf8ToBytes(value).length; // assume utf8
        }
        encoding = (encoding).toLowerCase();
        loweredCase = true;
    }
  }
}

class Buffer {
  late Uint8List _buf;
  // ignore: prefer_final_fields
  late String _encoding;
  static const bool _isBuffer = true;
  static const int poolSize = 8192; // not used by this implementation

  @DynamicTypeArgument('value', 'int | Uint8List | List<int> | String | Buffer')
  Buffer(dynamic value,
      [int length = 0, int offset = 0, String encoding = 'utf8'])
      : _encoding = encoding {
    switch (value.runtimeType) {
      case int:
        _buf = Uint8List(value as int);
        break;
      case Uint8List:
        _buf = Uint8List.fromList(value as Uint8List);
        break;
      case List<int>:
        _buf = Uint8List.fromList(value as List<int>);
        break;
      case Buffer:
        _buf = (value as Buffer)._buf;
        break;
      case String:
        _buf = Buffer.fromString(value as String)._buf;
        break;
      default:
        throw InvalidTypeError(
            'The first argument must be one of type String, Buffer, Uint8List, List<int> or int. Received type ${value.runtimeType}');
    }
  }

  operator [](int index) => _buf[index];
  operator []=(int index, int value) {
    _buf[index] = value;
  }

  // int byteLength(dynamic value, String encoding) =>
  //     _byteLength(value, encoding);

  int get _byteLength => byteLength(this, _encoding);

  int get offset => _buf.offsetInBytes;

  int get length => _byteLength;

  Uint8List get buffer => _buf;

  static int byteLength(dynamic value,
      [String encoding = 'utf8', bool mustMatch = true]) {
    if (value is String) {
      return value.length;
    }
    if (value is Uint8List) {
      return value.lengthInBytes;
    }
    if (value is Buffer) {
      return value._buf.lengthInBytes;
    }
    if (value is! String) {
      throw InvalidTypeError(
          'The "value" argument must be one of type String, Buffer, or Uint8List. '
          'Received type ${value.runtimeTypes}');
    }

    final len = value.length;
    if (!mustMatch && len == 0) return 0;

    // Use a for loop to avoid recursion
    bool loweredCase = false;
    for (;;) {
      switch (encoding) {
        case 'ascii':
        case 'latin1':
        case 'binary':
          return len;
        case 'utf8':
        case 'utf-8':
          return utf8ToBytes(value).length;
        case 'ucs2':
        case 'ucs-2':
        case 'utf16le':
        case 'utf-16le':
          return len * 2;
        case 'hex':
          return len >>> 1;
        case 'base64':
          return base64ToBytes(value).length;
        default:
          if (loweredCase) {
            return mustMatch ? -1 : utf8ToBytes(value).length; // assume utf8
          }
          encoding = (encoding).toLowerCase();
          loweredCase = true;
      }
    }
  }

  //*!includes
  bool includes(dynamic val, int byteOffset, String encoding) {
    return indexOf(val, byteOffset, encoding) != -1;
  }

  //*!indexOf
  int indexOf(dynamic val, int byteOffset, [String? encoding]) {
    return _buf.indexOf(val, byteOffset);
  }

  //*!lastIndexOf
  int lastIndexOf(dynamic val, int byteOffset, [String? encoding]) {
    return _buf.lastIndexOf(val, byteOffset);
  }

  //*!alloc method
  static Buffer alloc(int size, [dynamic fill, String? encoding]) {
    assertSize(size);
    if (size <= 0) {
      return createBuffer(size);
    }
    if (fill != null) {
      // Only pay attention to encoding if it's a string. This
      // prevents accidentally sending in a number that would
      // be interpreted as a start offset.
      return createBuffer(size).fill(fill);
    }
    return createBuffer(size);
  }

  //*!allocUnsafe method
  static Buffer allocUnsafe(int size) {
    assertSize(size);
    return createBuffer(size < 0 ? 0 : checked(size) | 0);
  }

  //*!isEncoding method
  static bool isEncoding(String encoding) {
    switch (encoding.toLowerCase()) {
      case 'hex':
      case 'utf8':
      case 'utf-8':
      case 'ascii':
      case 'latin1':
      case 'binary':
      case 'base64':
      case 'ucs2':
      case 'ucs-2':
      case 'utf16le':
      case 'utf-16le':
        return true;
      default:
        return false;
    }
  }

  //*!isBuffer method
  static bool isBuffer(dynamic b) {
    return b != null && b._isBuffer == true && b is Buffer;
  }

  //*!fromString method
  static Buffer fromString(String string, [String encoding = '']) {
    if (encoding == '') {
      encoding = 'utf8';
    }

    if (!Buffer.isEncoding(encoding)) {
      throw InvalidTypeError('Unknown encoding: $encoding');
    }

    final length = byteLength(string, encoding) | 0;
    var buf = createBuffer(length);

    final actual = buf.write(string, encoding: encoding);

    if (actual != length) {
      // Writing a hex string, for example, that contains invalid characters will
      // cause everything after the first invalid character to be ignored. (e.g.
      // 'abxxcd' will be treated as 'ab')
      buf = buf.slice(0, actual);
    }

    return buf;
  }

  //*!slowBuffer method
  Buffer slowBuffer(int length) {
    if (length.abs() != length) {
      // eslint-disable-line eqeqeq
      length = 0;
    }
    return Buffer.alloc(length.abs());
  }

  //*!from method
  static Buffer from(dynamic value,
      [int offset = 0, int length = 0, String encoding = 'utf8']) {
    if (value is String) {
      return fromString(value, encoding);
    }

    if (value is List<int>) {
      return fromArrayLike(value);
    }
    if (value is Iterable<int>) {
      return fromArrayLike(value.toList());
    }

    if (value is Buffer) {
      return fromArrayBuffer(value._buf, value.offset, value.length);
    }

    if (value is Uint8List) {
      return fromArrayBuffer(value, offset, length);
    }
    if (value == null) {
      throw InvalidTypeError(
          'The first argument must be one of type string, Buffer, Uint8List, List<int>, or Iterable<int>. Received type ${value.runtimeType}');
    }

    throw InvalidTypeError(
        'The first argument must be one of type string, Buffer, Uint8List, List<int>, or Iterable<int>. Received type ${value.runtimeType}');
  }

  //*! slice method
  Buffer slice(int start, int? end) {
    final len = length;
    start = ~~start;
    end = end == null ? len : ~~end;

    if (start < 0) {
      start += len;
      if (start < 0) {
        start = 0;
      }
    } else if (start > len) {
      start = len;
    }

    if (end < 0) {
      end += len;
      if (end < 0) {
        end = 0;
      }
    } else if (end > len) {
      end = len;
    }

    if (end < start) {
      end = start;
    }

    final newBuf = Buffer(_buf.sublist(start, end));
    // this.subarray(start, end);
    // Return an augmented `Uint8Array` instance
    // Object.setPrototypeOf(newBuf, Buffer.prototype)

    return newBuf;
  }

  //*! fill method
  Buffer fill(dynamic val,
      [int start = 0, int? end, String? encoding = 'utf8']) {
    // end ??= length;
    // Handle string cases:
    if (val is String) {
      if (encoding is String && !Buffer.isEncoding(encoding)) {
        throw InvalidTypeError('Unknown encoding: $encoding');
      }
      if (val.length == 1) {
        final code = val.codeUnitAt(0);
        if ((encoding == 'utf8' && code < 128) || encoding == 'latin1') {
          // Fast path: If `val` fits into a single byte, use that numeric value.
          val = code;
        }
      }
    } else if (val is int) {
      val = val & 255;
    } else if (val is bool) {
      val = val ? 1 : 0;
    }

    // Invalid ranges are not set to a default, so can range check early.
    if (start < 0 || length < start || (end != null && length < end)) {
      throw RangeError('Out of range index');
    }

    if (end != null && end <= start) {
      return this;
    }

    start = start >>> 0;
    end = end == null ? length : end >>> 0;

    if (!val) {
      val = 0;
    }

    int i;
    if (val is int) {
      for (i = start; i < end; ++i) {
        this[i] = val;
      }
    } else {
      final bytes =
          Buffer.isBuffer(val) ? val : Buffer.from(val, 0, 0, encoding!);
      final len = bytes.length;
      if (len == 0) {
        throw InvalidTypeError(
            'The value "$val" is invalid for argument "value"');
      }
      for (i = 0; i < end - start; ++i) {
        this[i + start] = bytes[i % len];
      }
    }

    return this;
  }

  //*!write method
  write(String string,
      {int offset = 0, int? length, String encoding = 'utf8'}) {
    // Buffer#write(string)
    if (length == null) {
      length = this.length;
      // Buffer#write(string, offset[, length][, encoding])
    } else if (offset.isFinite) {
      offset = offset >>> 0;
      if (length.isFinite) {
        length = length >>> 0;
      } else {
        throw ArgumentError(
            'Buffer.write(string, encoding, offset[, length]) is no longer supported');
      }

      final remaining = this.length - offset;
      if (length > remaining) {
        length = remaining;
      }

      if ((string.isNotEmpty && (length < 0 || offset < 0)) ||
          offset > this.length) {
        throw RangeError('Attempt to write outside buffer bounds');
      }

      bool loweredCase = false;
      for (;;) {
        switch (encoding) {
          case 'hex':
            return hexWrite(this, string, offset, length);

          case 'utf8':
          case 'utf-8':
            return utf8Write(this, string, offset, length);

          case 'ascii':
          case 'latin1':
          case 'binary':
            return asciiWrite(this, string, offset, length);

          case 'base64':
            // Warning: maxLength not taken into account in base64Write
            return base64Write(this, string, offset, length);

          case 'ucs2':
          case 'ucs-2':
          case 'utf16le':
          case 'utf-16le':
            return ucs2Write(this, string, offset, length);

          default:
            if (loweredCase) {
              throw InvalidTypeError('Unknown encoding: $encoding');
            }
            encoding = encoding.toLowerCase();
            loweredCase = true;
        }
      }
    }
  }

  //*!swap methods
  void swap(Buffer b, int n, int m) {
    int i = b[n];
    b[n] = b[m];
    b[m] = i;
  }

  Buffer swap16() {
    final len = length;
    if (len % 2 != 0) {
      throw RangeError('Buffer size must be a multiple of 16-bits');
    }
    for (int i = 0; i < len; i += 2) {
      swap(this, i, i + 1);
    }
    return this;
  }

  Buffer swap32() {
    final len = length;
    if (len % 4 != 0) {
      throw RangeError('Buffer size must be a multiple of 32-bits');
    }
    for (int i = 0; i < len; i += 4) {
      swap(this, i, i + 3);
      swap(this, i + 1, i + 2);
    }
    return this;
  }

  Buffer swap64() {
    final len = length;
    if (len % 8 != 0) {
      throw RangeError('Buffer size must be a multiple of 64-bits');
    }
    for (int i = 0; i < len; i += 8) {
      swap(this, i, i + 7);
      swap(this, i + 1, i + 6);
      swap(this, i + 2, i + 5);
      swap(this, i + 3, i + 4);
    }
    return this;
  }

  //*! toString_
  String toString_([Map<String, dynamic> arguments = const {}]) {
    final length = this.length;
    if (length == 0) {
      return '';
    }
    if (arguments.isEmpty) {
      return utf8Slice(this, 0, length);
    }
    return slowToString(
        arguments['encoding'], arguments['start'], arguments['end']);
  }

  //*! slowToString
  String slowToString(
      [String? encoding = 'utf8', int? start = 0, int? end = 0]) {
    bool loweredCase = false;

    // No need to verify that "this.length <= MAX_UINT32" since it's a read-only
    // property of a typed array.

    // This behaves neither like String nor Uint8Array in that we set start/end
    // to their upper/lower bounds if the value passed is out of range.
    // undefined is handled specially as per ECMA-262 6th Edition,
    // Section 13.3.3.7 Runtime Semantics: KeyedBindingInitialization.
    if (start == null || start < 0) {
      start = 0;
    }
    // Return early if start > this.length. Done here to prevent potential uint32
    // coercion fail below.
    if (start > length) {
      return '';
    }

    if (end == null || end > length) {
      end = length;
    }

    if (end <= 0) {
      return '';
    }

    // Force coercion to uint32. This will also coerce falsey/NaN values to 0.
    end >>>= 0;
    start >>>= 0;

    if (end <= start) {
      return '';
    }

    while (true) {
      switch (encoding) {
        case 'hex':
          return hexSlice(this, start, end);

        case 'utf8':
        case 'utf-8':
          return utf8Slice(this, start, end);

        case 'ascii':
          return asciiSlice(this, start, end);

        case 'latin1':
        case 'binary':
          return latin1Slice(this, start, end);

        case 'base64':
          return base64Slice(this, start, end);

        case 'ucs2':
        case 'ucs-2':
        case 'utf16le':
        case 'utf-16le':
          return utf16leSlice(this, start, end);

        default:
          if (loweredCase) {
            throw InvalidTypeError('Unknown encoding: $encoding');
          }
          encoding = (encoding)?.toLowerCase();
          loweredCase = true;
      }
    }
  }

  //*! equals
  bool equals(dynamic b) {
    if (!Buffer.isBuffer(b)) {
      throw InvalidTypeError('Argument must be a Buffer');
    }
    if (this == b) {
      return true;
    }
    return Buffer.compare(this, b) == 0;
  }

  //*! inspect
  String inspect() {
    String str = '';
    const max = INSPECT_MAX_BYTES;
    str = toString_({'encoding': 'hex', 'start': 0, 'end': max})
        .replaceAll(RegExp(r'/(.{2})/g'), r'$1 ')
        .trim();
    if (length > max) {
      str += ' ... ';
    }
    return '<Buffer $str>';
  }

  //*! static compare
  static int compare(dynamic a, dynamic b) {
    if (a is Uint8List || a is Buffer) {
      a = Buffer.from(a, a.offset, a.byteLength);
    }
    if (b is Uint8List || b is Buffer) {
      b = Buffer.from(b, b.offset, b.byteLength);
    }
    if (!Buffer.isBuffer(a) || !Buffer.isBuffer(b)) {
      throw InvalidTypeError(
          'The "buf1", "buf2" arguments must be one of type Buffer or Uint8Array');
    }

    if (a == b) {
      return 0;
    }

    int x = a.length;
    int y = b.length;

    for (int i = 0, len = min(x, y); i < len; ++i) {
      if (a[i] != b[i]) {
        x = a[i];
        y = b[i];
        break;
      }
    }

    if (x < y) {
      return -1;
    }
    if (y < x) {
      return 1;
    }
    return 0;
  }

  //*! instance compare
  int compareInstance(dynamic target,
      [int? start, int? end, int? thisStart, int? thisEnd]) {
    if (target is Uint8List) {
      target = Buffer.from(target, target.offsetInBytes, target.lengthInBytes);
    }
    if (target is Buffer) {
      target = Buffer.from(target, target.offset, target.length);
    }
    if (!Buffer.isBuffer(target)) {
      throw InvalidTypeError(
          'The "target" argument must be one of type Buffer or Uint8List. Received type  (${target.runtimeType})');
    }

    start ??= 0;
    end ??= target ? target.length : 0;
    thisStart ??= 0;
    thisEnd ??= length;

    if (start < 0 ||
        end! > target.length ||
        thisStart < 0 ||
        thisEnd > length) {
      throw RangeError('out of range index');
    }

    if (thisStart >= thisEnd && start >= end) {
      return 0;
    }
    if (thisStart >= thisEnd) {
      return -1;
    }
    if (start >= end) {
      return 1;
    }

    start >>>= 0;
    end >>>= 0;
    thisStart >>>= 0;
    thisEnd >>>= 0;

    if (this == target) return 0;

    int x = thisEnd - thisStart;
    int y = end - start;
    final len = min(x, y);

    final thisCopy = slice(thisStart, thisEnd);
    final targetCopy = target.slice(start, end);

    for (int i = 0; i < len; ++i) {
      if (thisCopy[i] != targetCopy[i]) {
        x = thisCopy[i];
        y = targetCopy[i];
        break;
      }
    }

    if (x < y) return -1;
    if (y < x) return 1;
    return 0;
  }

  //*! concat
  static Buffer concat(List<Buffer> list, [int? length]) {
    if (list.isEmpty) {
      return Buffer.alloc(0);
    }

    int i;
    if (length == null) {
      length = 0;
      for (i = 0; i < list.length; ++i) {
        length = length! + list[i].length;
      }
    }

    Buffer buffer = Buffer.allocUnsafe(length!);
    int pos = 0;
    for (i = 0; i < list.length; ++i) {
      Buffer? buf = list[i];
      if (Buffer.isBuffer(buf)) {
        if (pos + buf.length > buffer.length) {
          if (!Buffer.isBuffer(buf)) {
            buf = Buffer.from(buf);
          }
          buf.copy(buffer, pos);
        } else {
          // Uint8Array.prototype.set.call(buffer, buf, pos);
          buffer = Buffer.from(buf, pos);
        }
      } else if (!Buffer.isBuffer(buf)) {
        throw InvalidTypeError('"list" argument must be an Array of Buffers');
      } else {
        buf.copy(buffer, pos);
      }
      pos += buf.length;
    }
    return buffer;
  }

  //* copy(targetBuffer, targetStart=0, sourceStart=0, sourceEnd=buffer.length)
  //*!copy
  int copy(Buffer target, [int targetStart = 0, int start = 0, int end = 0]) {
    if (!Buffer.isBuffer(target)) {
      throw InvalidTypeError('argument should be a Buffer');
    }
    if (end != 0) {
      end = length;
    }
    if (targetStart >= target.length) {
      targetStart = target.length;
    }

    if (end > 0 && end < start) {
      end = start;
    }

    // Copy 0 bytes; we're done
    if (end == start) {
      return 0;
    }
    if (target.length == 0 || length == 0) {
      return 0;
    }

    // Fatal error conditions
    if (targetStart < 0) {
      throw RangeError('targetStart out of bounds');
    }
    if (start < 0 || start >= length) {
      throw RangeError('Index out of range');
    }
    if (end < 0) {
      throw RangeError('sourceEnd out of bounds');
    }

    // Are we oob?
    if (end > length) {
      end = length;
    }
    if (target.length - targetStart < end - start) {
      end = target.length - targetStart + start;
    }

    final len = end - start;

    if (this == target) {
      // Use built-in when available, missing from IE11
      // this.copyWithin(targetStart, start, end);
      _buf.setAll(targetStart, _buf.sublist(start, end));
    } else {
      // Uint8Array.prototype.set
      //     .call(target, this.subarray(start, end), targetStart);
      target = Buffer(target._buf.sublist(start, end), targetStart);
    }

    return len;
  }

  //*! read int methods
  int readUIntLE(int offset, int byteLength, [bool noAssert = false]) {
    offset = offset >>> 0;
    byteLength = byteLength >>> 0;
    if (!noAssert) {
      checkOffset(offset, byteLength, length);
    }

    int val = this[offset];
    int mul = 1;
    int i = 0;
    while (++i < byteLength && (mul *= 0x100) != 0) {
      val += this[offset + i] * mul as int;
    }

    return val;
  }

  int readUIntBE(int offset, int byteLength, [bool noAssert = false]) {
    offset = offset >>> 0;
    byteLength = byteLength >>> 0;
    if (!noAssert) {
      checkOffset(offset, byteLength, length);
    }

    int val = this[offset + --byteLength];
    int mul = 1;
    while (byteLength > 0 && (mul *= 0x100) != 0) {
      val += this[offset + --byteLength] * mul as int;
    }

    return val;
  }

  int readUInt8(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) checkOffset(offset, 1, length);
    return this[offset];
  }

  int readUInt16LE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 2, length);
    }
    return this[offset] | (this[offset + 1] << 8);
  }

  int readUInt16BE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 2, length);
    }
    return (this[offset] << 8) | this[offset + 1];
  }

  int readUInt32LE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 4, length);
    }

    return ((this[offset]) |
            (this[offset + 1] << 8) |
            (this[offset + 2] << 16)) +
        (this[offset + 3] * 0x1000000);
  }

  int readUInt32BE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 4, length);
    }
    return (this[offset] * 0x1000000) +
        ((this[offset + 1] << 16) | (this[offset + 2] << 8) | this[offset + 3]);
  }

  int readIntLE(int offset, int byteLength, [bool noAssert = false]) {
    offset = offset >>> 0;
    byteLength = byteLength >>> 0;
    if (!noAssert) {
      checkOffset(offset, byteLength, length);
    }

    int val = this[offset];
    int mul = 1;
    int i = 0;
    while (++i < byteLength && (mul *= 0x100) != 0) {
      val += this[offset + i] * mul as int;
    }
    mul *= 0x80;

    if (val >= mul) val -= pow(2, 8 * byteLength) as int;

    return val;
  }

  int readIntBE(int offset, int byteLength, [bool noAssert = false]) {
    offset = offset >>> 0;
    byteLength = byteLength >>> 0;
    if (!noAssert) {
      checkOffset(offset, byteLength, length);
    }

    int i = byteLength;
    int mul = 1;
    int val = this[offset + --i];
    while (i > 0 && (mul *= 0x100) != 0) {
      val += this[offset + --i] * mul as int;
    }
    mul *= 0x80;

    if (val >= mul) {
      val -= pow(2, 8 * byteLength) as int;
    }

    return val;
  }

  int readInt8(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 1, length);
    }
    if (!(this[offset] & 0x80)) {
      return (this[offset]);
    }
    return ((0xff - this[offset] + 1) * -1) as int;
  }

  int readInt16LE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 2, length);
    }
    final val = this[offset] | (this[offset + 1] << 8);
    return (val & 0x8000) ? val | 0xFFFF0000 : val;
  }

  int readInt16BE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 2, length);
    }
    final val = this[offset + 1] | (this[offset] << 8);
    return (val & 0x8000) ? val | 0xFFFF0000 : val;
  }

  int readInt32LE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 4, length);
    }

    return (this[offset]) |
        (this[offset + 1] << 8) |
        (this[offset + 2] << 16) |
        (this[offset + 3] << 24);
  }

  int readInt32BE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 4, length);
    }

    return (this[offset] << 24) |
        (this[offset + 1] << 16) |
        (this[offset + 2] << 8) |
        (this[offset + 3]);
  }

  //* read float & double methods
  int readFloatLE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 4, length);
    }
    return Ieee754.read(_buf, offset, true, 23, 4);
  }

  readFloatBE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 4, length);
    }
    return Ieee754.read(_buf, offset, false, 23, 4);
  }

  readDoubleLE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 8, length);
    }
    return Ieee754.read(_buf, offset, true, 52, 8);
  }

  readDoubleBE(int offset, [bool noAssert = false]) {
    offset = offset >>> 0;
    if (!noAssert) {
      checkOffset(offset, 8, length);
    }
    return Ieee754.read(_buf, offset, false, 52, 8);
  }

  //*write int methods
  int writeUIntLE(int value, int offset, int byteLength,
      [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    byteLength = byteLength >>> 0;
    if (!noAssert) {
      final maxBytes = pow(2, 8 * byteLength) - 1;
      checkInt(this, value, offset, byteLength, maxBytes, 0);
    }

    int mul = 1;
    int i = 0;
    this[offset] = value & 0xFF;
    while (++i < byteLength && (mul *= 0x100) != 0) {
      this[offset + i] = (value ~/ mul) & 0xFF;
    }

    return offset + byteLength;
  }

  int writeUIntBE(int value, int offset, int byteLength,
      [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    byteLength = byteLength >>> 0;
    if (!noAssert) {
      final maxBytes = pow(2, 8 * byteLength) - 1;
      checkInt(this, value, offset, byteLength, maxBytes, 0);
    }

    int i = byteLength - 1;
    int mul = 1;
    this[offset + i] = value & 0xFF;
    while (--i >= 0 && (mul *= 0x100) != 0) {
      this[offset + i] = (value ~/ mul) & 0xFF;
    }

    return offset + byteLength;
  }

  int writeUInt8(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 1, 0xff, 0);
    }
    this[offset] = (value & 0xff);
    return offset + 1;
  }

  int writeUInt16LE(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 2, 0xffff, 0);
    }
    this[offset] = (value & 0xff);
    this[offset + 1] = (value >>> 8);
    return offset + 2;
  }

  int writeUInt16BE(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 2, 0xffff, 0);
    }
    this[offset] = (value >>> 8);
    this[offset + 1] = (value & 0xff);
    return offset + 2;
  }

  int writeUInt32LE(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 4, 0xffffffff, 0);
    }
    this[offset + 3] = (value >>> 24);
    this[offset + 2] = (value >>> 16);
    this[offset + 1] = (value >>> 8);
    this[offset] = (value & 0xff);
    return offset + 4;
  }

  int writeUInt32BE(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 4, 0xffffffff, 0);
    }
    this[offset] = (value >>> 24);
    this[offset + 1] = (value >>> 16);
    this[offset + 2] = (value >>> 8);
    this[offset + 3] = (value & 0xff);
    return offset + 4;
  }

  int writeIntLE(int value, int offset, int byteLength,
      [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      final limit = pow(2, (8 * byteLength) - 1);

      checkInt(this, value, offset, byteLength, limit - 1, -limit);
    }

    int i = 0;
    int mul = 1;
    int sub = 0;
    this[offset] = value & 0xFF;
    while (++i < byteLength && (mul *= 0x100) != 0) {
      if (value < 0 && sub == 0 && this[offset + i - 1] != 0) {
        sub = 1;
      }
      this[offset + i] = ((value ~/ mul) >> 0) - sub & 0xFF;
    }

    return offset + byteLength;
  }

  int writeIntBE(int value, int offset, int byteLength,
      [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      final limit = pow(2, (8 * byteLength) - 1);

      checkInt(this, value, offset, byteLength, limit - 1, -limit);
    }

    int i = byteLength - 1;
    int mul = 1;
    int sub = 0;
    this[offset + i] = value & 0xFF;
    while (--i >= 0 && (mul *= 0x100) != 0) {
      if (value < 0 && sub == 0 && this[offset + i + 1] != 0) {
        sub = 1;
      }
      this[offset + i] = ((value ~/ mul) >> 0) - sub & 0xFF;
    }

    return offset + byteLength;
  }

  int writeInt8(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 1, 0x7f, -0x80);
    }
    if (value < 0) {
      value = 0xff + value + 1;
    }
    this[offset] = (value & 0xff);
    return offset + 1;
  }

  int writeInt16LE(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 2, 0x7fff, -0x8000);
    }
    this[offset] = (value & 0xff);
    this[offset + 1] = (value >>> 8);
    return offset + 2;
  }

  int writeInt16BE(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 2, 0x7fff, -0x8000);
    }
    this[offset] = (value >>> 8);
    this[offset + 1] = (value & 0xff);
    return offset + 2;
  }

  int writeInt32LE(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 4, 0x7fffffff, -0x80000000);
    }
    this[offset] = (value & 0xff);
    this[offset + 1] = (value >>> 8);
    this[offset + 2] = (value >>> 16);
    this[offset + 3] = (value >>> 24);
    return offset + 4;
  }

  int writeInt32BE(int value, int offset, [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkInt(this, value, offset, 4, 0x7fffffff, -0x80000000);
    }
    if (value < 0) {
      value = 0xffffffff + value + 1;
    }
    this[offset] = (value >>> 24);
    this[offset + 1] = (value >>> 16);
    this[offset + 2] = (value >>> 8);
    this[offset + 3] = (value & 0xff);
    return offset + 4;
  }

  //* write float & double methods
  void checkIEEE754(
      Buffer buf, double value, int offset, int ext, double max, double min) {
    if (offset + ext > buf.length) throw RangeError('Index out of range');
    if (offset < 0) throw RangeError('Index out of range');
  }

  int writeFloat(Buffer buf, double value, int offset, bool littleEndian,
      [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkIEEE754(buf, value, offset, 4, 3.4028234663852886e+38,
          -3.4028234663852886e+38);
    }
    Ieee754.write(buf._buf, value, offset, littleEndian, 23, 4);
    return offset + 4;
  }

  int writeDouble(Buffer buf, double value, int offset, bool littleEndian,
      [bool noAssert = false]) {
    value = value.abs();
    offset = offset >>> 0;
    if (!noAssert) {
      checkIEEE754(buf, value, offset, 8, 1.7976931348623157E+308,
          -1.7976931348623157E+308);
    }
    Ieee754.write(buf._buf, value, offset, littleEndian, 52, 8);
    return offset + 8;
  }

  writeFloatLE(double value, int offset, [bool noAssert = false]) {
    return writeFloat(this, value, offset, true, noAssert);
  }

  writeFloatBE(double value, int offset, [bool noAssert = false]) {
    return writeFloat(this, value, offset, false, noAssert);
  }

  writeDoubleLE(double value, int offset, [bool noAssert = false]) {
    return writeDouble(this, value, offset, true, noAssert);
  }

  writeDoubleBE(double value, int offset, [bool noAssert = false]) {
    return writeDouble(this, value, offset, false, noAssert);
  }

  //* read big int methods

  BigInt readBigUInt64LE(int offset) {
    offset = offset >>> 0;
    validateNumber(offset, 'offset');
    final first = this[offset];
    final last = this[offset + 7];
    if (first == null || last == null) {
      boundsError(offset, length - 8);
    }

    final lo = first +
        this[++offset] * pow(2, 8) +
        this[++offset] * pow(2, 16) +
        this[++offset] * pow(2, 24);

    final hi = this[++offset] +
        this[++offset] * pow(2, 8) +
        this[++offset] * pow(2, 16) +
        last * pow(2, 24);

    return BigInt.from(lo) + (BigInt.from(hi) << BigInt.from(32).toInt());
  }

  BigInt readBigUInt64BE(int offset) {
    offset = offset >>> 0;
    validateNumber(offset, 'offset');
    final first = this[offset];
    final last = this[offset + 7];
    if (first == null || last == null) {
      boundsError(offset, length - 8);
    }

    final hi = first * pow(2, 24) +
        this[++offset] * pow(2, 16) +
        this[++offset] * pow(2, 8) +
        this[++offset];

    final lo = this[++offset] * pow(2, 24) +
        this[++offset] * pow(2, 16) +
        this[++offset] * pow(2, 8) +
        last;

    return (BigInt.from(hi) << BigInt.from(32).toInt()) + BigInt.from(lo);
  }

  BigInt readBigInt64LE(int offset) {
    offset = offset >>> 0;
    validateNumber(offset, 'offset');
    final first = this[offset];
    final last = this[offset + 7];
    if (first == null || last == null) {
      boundsError(offset, length - 8);
    }

    final val = this[offset + 4] +
        this[offset + 5] * pow(2, 8) +
        this[offset + 6] * pow(2, 16) +
        (last << 24); // Overflow

    return (BigInt.from(val) << BigInt.from(32).toInt()) +
        BigInt.from(first +
            this[++offset] * pow(2, 8) +
            this[++offset] * pow(2, 16) +
            this[++offset] * pow(2, 24));
  }

  BigInt readBigInt64BE(int offset) {
    offset = offset >>> 0;
    validateNumber(offset, 'offset');
    final first = this[offset];
    final last = this[offset + 7];
    if (first == null || last == null) {
      boundsError(offset, length - 8);
    }

    final val = (first << 24) + // Overflow
        this[++offset] * pow(2, 16) +
        this[++offset] * pow(2, 8) +
        this[++offset];

    return (BigInt.from(val) << BigInt.from(32).toInt()) +
        BigInt.from(this[++offset] * pow(2, 24) +
            this[++offset] * pow(2, 16) +
            this[++offset] * pow(2, 8) +
            last);
  }

  //* write bigInt methods

  int wrtBigUInt64LE(Buffer buf, int value, int offset, int min, int max) {
    checkIntBI(value, min, max, buf, offset, 7);

    int lo = value & BigInt.from(0xffffffff).toInt();
    buf[offset++] = lo;
    lo = lo >> 8;
    buf[offset++] = lo;
    lo = lo >> 8;
    buf[offset++] = lo;
    lo = lo >> 8;
    buf[offset++] = lo;
    int hi =
        (value >> BigInt.from(32).toInt() & BigInt.from(0xffffffff).toInt());
    buf[offset++] = hi;
    hi = hi >> 8;
    buf[offset++] = hi;
    hi = hi >> 8;
    buf[offset++] = hi;
    hi = hi >> 8;
    buf[offset++] = hi;
    return offset;
  }

  int wrtBigUInt64BE(Buffer buf, int value, int offset, int min, int max) {
    checkIntBI(value, min, max, buf, offset, 7);

    int lo = (value & BigInt.from(0xffffffff).toInt());
    buf[offset + 7] = lo;
    lo = lo >> 8;
    buf[offset + 6] = lo;
    lo = lo >> 8;
    buf[offset + 5] = lo;
    lo = lo >> 8;
    buf[offset + 4] = lo;
    int hi =
        (value >> BigInt.from(32).toInt() & BigInt.from(0xffffffff).toInt());
    buf[offset + 3] = hi;
    hi = hi >> 8;
    buf[offset + 2] = hi;
    hi = hi >> 8;
    buf[offset + 1] = hi;
    hi = hi >> 8;
    buf[offset] = hi;
    return offset + 8;
  }

  int writeBigUInt64LE(int value, [int offset = 0]) {
    return wrtBigUInt64LE(
      this,
      value,
      offset,
      BigInt.from(0).toInt(),
      BigInt.from(0xffffffffffffffff).toInt(),
    );
  }

  int writeBigUInt64BE(int value, [int offset = 0]) {
    return wrtBigUInt64BE(
      this,
      value,
      offset,
      BigInt.from(0).toInt(),
      BigInt.from(0xffffffffffffffff).toInt(),
    );
  }

  int writeBigInt64LE(int value, [int offset = 0]) {
    return wrtBigUInt64LE(
      this,
      value,
      offset,
      -BigInt.from(0x8000000000000000).toInt(),
      BigInt.from(0x7fffffffffffffff).toInt(),
    );
  }

  int writeBigInt64BE(int value, [int offset = 0]) {
    return wrtBigUInt64BE(
      this,
      value,
      offset,
      -BigInt.from(0x8000000000000000).toInt(),
      BigInt.from(0x7fffffffffffffff).toInt(),
    );
  }
}
