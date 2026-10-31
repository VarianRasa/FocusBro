class LocalIdGenerator {
  LocalIdGenerator._();

  static int _lastValue = 0;

  static String next() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    _lastValue = timestamp > _lastValue ? timestamp : _lastValue + 1;
    return _lastValue.toString();
  }
}
