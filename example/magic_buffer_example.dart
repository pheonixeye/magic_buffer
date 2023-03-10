void main(List<String> args) {
  const str = 'dartedious';
  print(str.length.toRadixString(2));
  print((str.length >>> 1).toRadixString(2));
}
