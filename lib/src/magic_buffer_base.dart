import 'dart:math';
import 'dart:typed_data';

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

int _byteLength(dynamic value,
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

  int get byteLength => _byteLength(this, _encoding);

  int get offset => _buf.offsetInBytes;

  int get length => byteLength;

  Uint8List get buffer => _buf;
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
      return encoding is String
          ? createBuffer(size).fill(fill, 0, 0, encoding)
          : createBuffer(size).fill(fill);
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

    final length = _byteLength(string, encoding) | 0;
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
      return fromArrayBuffer(value._buf, value.offset, value.byteLength);
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
      target = Buffer.from(target, target.offset, target.byteLength);
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
}
