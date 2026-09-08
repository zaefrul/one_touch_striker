import 'dart:typed_data';

/// Fixed-duration trail with reusable storage. Samples are taken every 12 ms,
/// interpolating within a rendered frame instead of dropping its remainder.
/// This avoids changing trail length/cadence between 60, 90 and 120 Hz screens.
class ShotTrail {
  static const capacity = 14;
  static const interval = .012;
  final Float64List _xs = Float64List(capacity);
  final Float64List _ys = Float64List(capacity);
  int _writeIndex = 0;
  int _length = 0;
  double _remainder = 0;

  int get length => _length;
  double xAt(int index) => _xs[(_writeIndex - _length + index) % capacity];
  double yAt(int index) => _ys[(_writeIndex - _length + index) % capacity];

  void clear() {
    _writeIndex = 0;
    _length = 0;
    _remainder = 0;
  }

  void sample(double dt, double fromX, double fromY, double toX, double toY) {
    if (dt <= 0) {
      return;
    }
    var sampleAt = interval - _remainder;
    while (sampleAt <= dt + 1e-10) {
      final t = (sampleAt / dt).clamp(0.0, 1.0);
      _xs[_writeIndex] = fromX + (toX - fromX) * t;
      _ys[_writeIndex] = fromY + (toY - fromY) * t;
      _writeIndex = (_writeIndex + 1) % capacity;
      if (_length < capacity) {
        _length++;
      }
      sampleAt += interval;
    }
    _remainder = (dt - (sampleAt - interval)).clamp(0.0, interval).toDouble();
  }
}
