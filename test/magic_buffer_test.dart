import 'dart:typed_data';

import 'package:magic_buffer_copy/magic_buffer.dart';
import 'package:test/test.dart';

void main() {
  group('Buffer Constructor init', () {
    test('buffer constructor init<int>', () {
      final buffer = Buffer(8);
      expect(buffer.length, 8);
    });
    test('buffer constructor init<Uint8List>', () {
      final uint8List = Uint8List(8);
      final buffer = Buffer(uint8List);
      expect(buffer.length, 8);
    });
    test('buffer constructor init<String>', () {
      final string = 'darTedious';
      final buffer = Buffer(string);
      expect(buffer.length, 10);
    });
    test('buffer constructor init<Buffer>', () {
      final testBuffer = Buffer('Dartedious', 0, 0, 'utf8');
      final buffer = Buffer(testBuffer);
      expect(buffer.length, 10);
    });
  });

  group('byteLength Function', () {
    test('static byteLength utf8 encoding', () {
      final buffer = Buffer('DarTedious');
      expect(Buffer.byteLength(buffer), 10);
    });
    test('static byteLength ucs2 encoding', () {
      final buffer = Buffer('DarTedious', 0, 0, 'ucs2');
      expect(Buffer.byteLength(buffer, 'ucs2'), 20);
    });
  });

  group("buffer.write()\n", () {
    test('utf8 write method', () {
      final buffer = Buffer.from('DarTedious', 0, 0, 'utf8');
      print(buffer.length);
      final string = buffer.toString_({'encoding': 'utf8'});
      print(string);
      expect(string, 'DarTedious');
    });
    test('ucs2 write method', () {
      final buffer = Buffer.from('DarTedious', 0, 0, 'ucs2');
      print(buffer.length);
      final string = buffer.toString_({'encoding': 'ucs2'});
      print(string);
      expect(string, 'DarTedious');
    });
    test('hex write method', () {
      final buffer = Buffer.from(
          [0x44, 0x61, 0x72, 0x54, 0x65, 0x64, 0x69, 0x6f, 0x75, 0x73],
          0,
          0,
          'hex');
      print(buffer.length);
      final string = buffer.toString_({'encoding': 'utf8'});
      print(string);
      expect(string, 'DarTedious');
    });
    test('utf8 to hex write method', () {
      final buffer = Buffer.from('DarTedious', 0, 0, 'utf8');
      print(buffer.length);
      final string = buffer.toString_({'encoding': 'hex'});
      print(string);
      expect(string, '446172546564696f7573');
    });
    test('base64 write method', () {
      final buffer = Buffer.from('RGFyVGVkaW91cw==', 0, 0, 'base64');
      print(buffer.length);
      final string = buffer.toString_({'encoding': 'utf8'});
      print(string);
      expect(string, 'DarTedious');
    });
  });

  group('static Buffer Functions ==>> \n', () {
    test('Buffer.alloc()', () {
      final uint8List = Uint8List(20);
      uint8List.fillRange(0, uint8List.length, 0);
      final buffer = Buffer.alloc(20, 0);
      expect(buffer.length, 20);
      expect(buffer.buffer, uint8List);
    });
    test('Buffer.concat()', () {
      int i = 0;
      for (var j = 0; j < 10; j++) {
        i += j;
      }
      print(i);
      List<Buffer> list_ = [];
      for (var i = 0; i < 10; i++) {
        final list = List.generate(i, (index) => i);
        final uint8List = Uint8List.fromList(list);
        list_.add(Buffer(uint8List));
      }
      final buffer = Buffer.concat(list_);
      expect(buffer.length, i);
    });
    test('buffer.copy()', () {
      final buffer = Buffer(Uint8List.fromList([0, 1, 2, 3, 4, 5]));
      final buffer2 = Buffer(Uint8List.fromList([6, 7, 8, 9]));
      buffer.copy(buffer2, 0, 0);
      print(buffer.buffer);
      expect(buffer.buffer, [6, 7, 8, 9, 4, 5]);
    });
  });
}
