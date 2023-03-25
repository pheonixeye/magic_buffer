import 'dart:typed_data';

import 'package:magic_buffer/magic_buffer.dart';
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
      final testBuffer = Buffer('Dartedious', 'utf8');
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
      final buffer = Buffer('DarTedious', 'ucs2');
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
    test('Buffer.concat() ==>> length', () {
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
    test('Buffer.concat() ==>> content', () {
      final uin8List1 = Uint8List(5);
      uin8List1.setAll(0, [0, 1, 2, 3, 4]);
      final uin8List2 = Uint8List(5);
      uin8List2.setAll(0, [5, 6, 7, 8, 9]);
      var b1 = Buffer(uin8List1);
      var b2 = Buffer(uin8List2);
      b1 = Buffer.concat([b1, b2]);
      print('b1.buffer');
      print(b1.buffer);
      expect(b1.buffer, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });

    test('buffer.copy()', () {
      final b1 = Buffer(Uint8List.fromList([1, 2, 3, 4, 5]));
      final b2 = Buffer(Uint8List(3));

      final len = b1.copy(b2, 0, 1, 4);

      expect(len, equals(3));
      expect(b2.buffer, equals(Buffer(Uint8List.fromList([2, 3, 4])).buffer));
    });

    test('buffer.slice()', () {
      final buffer = Buffer.from(Uint8List.fromList([0, 1, 2, 3, 4]));
      final sliced = buffer.slice(1, 3);
      print(sliced.buffer);
      expect(sliced.buffer, [1, 2]);
    });
  });

  group('operators', () {
    test('[]', () {
      final uint8List = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final buffer = Buffer(uint8List);
      final selected = buffer[3];
      expect(selected, 3);
    });
    test('[]=', () {
      final uint8List = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final buffer = Buffer(uint8List);
      buffer[3] = 9;
      expect(buffer[3], 9);
      expect(buffer.buffer, [0, 1, 2, 9, 4, 5]);
    });
  });
}
