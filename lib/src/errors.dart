class InvalidTypeError extends Error {
  final String message;
  InvalidTypeError([this.message = '']);

  @override
  String toString() => message;
}
