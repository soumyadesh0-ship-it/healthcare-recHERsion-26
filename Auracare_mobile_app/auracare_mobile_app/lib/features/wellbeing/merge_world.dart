import 'dart:math' as math;

/// Circle physics in logical world units. Rendering scales the whole world
/// uniformly, so the same value-to-radius mapping applies on every device.
class MergeBall {
  MergeBall({
    required this.id,
    required this.value,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
  }) : previousX = x,
       previousY = y;
  final int id, value;
  double x, y, vx, vy;
  double previousX, previousY;
  double age = 0, quietTime = 0, overflowTime = 0;
  bool touching = false;
  double get radius => MergeWorld.radiusFor(value);
  bool get settled => age > .8 && quietTime >= .55;
}

class MergeWorld {
  MergeWorld({math.Random? random}) : _random = random ?? math.Random() {
    nextValue = _roll();
  }
  static const width = 100.0, height = 140.0, overflowLine = 23.0;
  static const fixedStep = 1 / 120, overflowGrace = 1.8;
  static double radiusFor(int value) => 2.6 + .8 * value;
  final math.Random _random;
  final List<MergeBall> _balls = [];
  List<MergeBall> get balls => List.unmodifiable(_balls);
  int _id = 0, score = 0;
  late int nextValue;
  double _accumulator = 0, _cooldown = 0;
  bool paused = false, gameOver = false;
  bool get canDrop => !paused && !gameOver && _cooldown <= 0;
  int _roll() => 1 + _random.nextInt(5);
  bool drop(double x) {
    if (!canDrop) return false;
    final r = radiusFor(nextValue);
    _balls.add(
      MergeBall(
        id: ++_id,
        value: nextValue,
        x: x.clamp(r, width - r),
        y: r + 1,
      ),
    );
    nextValue = _roll();
    _cooldown = .45;
    return true;
  }

  void restart() {
    _balls.clear();
    score = 0;
    _id = 0;
    _accumulator = 0;
    _cooldown = 0;
    gameOver = false;
    paused = false;
    nextValue = _roll();
  }

  void advance(double elapsed) {
    if (paused || gameOver || !elapsed.isFinite || elapsed <= 0) return;
    _accumulator += elapsed.clamp(0, .1);
    while (_accumulator >= fixedStep && !gameOver) {
      _step(fixedStep);
      _accumulator -= fixedStep;
    }
  }

  static bool canMerge(MergeBall a, MergeBall b) =>
      a.id != b.id && a.value == b.value && a.value + b.value <= 10;

  void _step(double dt) {
    _cooldown = math.max(0, _cooldown - dt);
    for (final b in _balls) {
      b.previousX = b.x;
      b.previousY = b.y;
      b.age += dt;
      b.touching = false;
      b.vy = (b.vy + 120 * dt).clamp(-180, 180);
      b.vx *= math.exp(-.7 * dt);
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }
    // Detect and queue contacts before changing membership. Each ID is reserved
    // once, so simultaneous contacts cannot consume a ball twice.
    final queued = <(MergeBall, MergeBall)>[];
    final reserved = <int>{};
    for (var iteration = 0; iteration < 8; iteration++) {
      for (final b in _balls) {
        _walls(b);
      }
      for (var i = 0; i < _balls.length; i++) {
        for (var j = i + 1; j < _balls.length; j++) {
          final a = _balls[i], b = _balls[j];
          final dx = b.x - a.x, dy = b.y - a.y, combined = a.radius + b.radius;
          final d2 = dx * dx + dy * dy;
          if (d2 > (combined + .03) * (combined + .03)) continue;
          a.touching = true;
          b.touching = true;
          if (canMerge(a, b) &&
              !reserved.contains(a.id) &&
              !reserved.contains(b.id)) {
            queued.add((a, b));
            reserved.addAll([a.id, b.id]);
          }
          final distance = math.sqrt(d2);
          final nx = distance < .0001 ? 1.0 : dx / distance,
              ny = distance < .0001 ? 0.0 : dy / distance;
          final ia = 1 / (a.radius * a.radius),
              ib = 1 / (b.radius * b.radius),
              total = ia + ib;
          final penetration = combined - distance;
          if (penetration > 0) {
            final correction = (penetration + .001) * .85 / total;
            a.x -= nx * correction * ia;
            a.y -= ny * correction * ia;
            b.x += nx * correction * ib;
            b.y += ny * correction * ib;
          }
          final relative = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
          if (relative < 0) {
            final impulse = -(1.03) * relative / total;
            a.vx -= impulse * nx * ia;
            a.vy -= impulse * ny * ia;
            b.vx += impulse * nx * ib;
            b.vy += impulse * ny * ib;
          }
        }
      }
    }
    // World mutation occurs only after all contact iteration has finished.
    if (queued.isNotEmpty) {
      final added = <MergeBall>[];
      for (final pair in queued) {
        final a = pair.$1,
            b = pair.$2,
            value = a.value + b.value,
            r = radiusFor(value);
        added.add(
          MergeBall(
            id: ++_id,
            value: value,
            x: ((a.x + b.x) / 2).clamp(r, width - r),
            y: math.min(height - r, (a.y + b.y) / 2),
            vx: (a.vx + b.vx) / 2,
            vy: (a.vy + b.vy) / 2,
          ),
        );
        score += value;
      }
      _balls.removeWhere((b) => reserved.contains(b.id));
      _balls.addAll(added);
      // New larger circles are separated on the next fixed step. They cannot
      // merge again within this same contact batch; chains continue next step.
    }
    for (final b in _balls) {
      _walls(b);
      final dx = b.x - b.previousX, dy = b.y - b.previousY;
      // Support impulses can leave tiny residual velocities in a tall stack.
      // Actual positional stillness, plus a speed bound, identifies rest.
      if (b.touching &&
          dx * dx + dy * dy < .0009 &&
          b.vx * b.vx + b.vy * b.vy < 64) {
        b.quietTime += dt;
      } else {
        b.quietTime = 0;
      }
      if (b.settled && b.y - b.radius < overflowLine) {
        b.overflowTime += dt;
      } else {
        b.overflowTime = 0;
      }
      if (b.overflowTime >= overflowGrace) {
        gameOver = true;
      }
    }
  }

  void _walls(MergeBall b) {
    final r = b.radius;
    if (b.x < r) {
      b.x = r;
      if (b.vx < 0) b.vx = -b.vx * .12;
      b.touching = true;
    }
    if (b.x > width - r) {
      b.x = width - r;
      if (b.vx > 0) b.vx = -b.vx * .12;
      b.touching = true;
    }
    if (b.y > height - r) {
      b.y = height - r;
      if (b.vy > 0) b.vy = b.vy < 4 ? 0 : -b.vy * .06;
      b.vx *= .97;
      b.touching = true;
    }
  }

  /// Deterministic fixture seam for physics tests; never used to seed gameplay.
  void addFixture({
    required int value,
    required double x,
    required double y,
    double vx = 0,
    double vy = 0,
  }) {
    if (value < 1 || value > 10) throw ArgumentError.value(value);
    _balls.add(MergeBall(id: ++_id, value: value, x: x, y: y, vx: vx, vy: vy));
  }
}
