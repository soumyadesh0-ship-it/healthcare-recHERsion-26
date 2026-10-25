import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/features/wellbeing/merge_world.dart';

void simulate(MergeWorld world, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) {
    world.advance(MergeWorld.fixedStep);
  }
}

void main() {
  for (var value = 1; value <= 5; value++) {
    test('touching $value + $value merges once to ${value * 2}', () {
      final world = MergeWorld(random: math.Random(1));
      world.addFixture(value: value, x: 30, y: 100);
      world.addFixture(
        value: value,
        x: 30 + 2 * MergeWorld.radiusFor(value),
        y: 100,
      );
      world.advance(MergeWorld.fixedStep);
      expect(world.balls, hasLength(1));
      expect(world.balls.single.value, value * 2);
      expect(world.score, value * 2);
    });
  }
  test('different and non-touching balls never merge', () {
    final world = MergeWorld();
    world.addFixture(value: 1, x: 30, y: 100);
    world.addFixture(value: 2, x: 37, y: 100);
    world.advance(MergeWorld.fixedStep);
    expect(world.balls, hasLength(2));
    expect(world.score, 0);
    final distant = MergeWorld();
    distant.addFixture(value: 1, x: 10, y: 100);
    distant.addFixture(value: 1, x: 80, y: 100);
    distant.advance(MergeWorld.fixedStep);
    expect(distant.balls, hasLength(2));
  });
  test('values above 5 do not merge into results beyond 10', () {
    for (var value = 6; value <= 10; value++) {
      final world = MergeWorld();
      world.addFixture(value: value, x: 30, y: 100);
      world.addFixture(
        value: value,
        x: 30 + 2 * MergeWorld.radiusFor(value),
        y: 100,
      );
      world.advance(MergeWorld.fixedStep);
      expect(world.balls, hasLength(2));
      expect(world.score, 0);
      expect(world.balls.every((b) => b.value <= 10), isTrue);
    }
  });
  test('a shared collision cannot consume the same ball twice', () {
    final world = MergeWorld();
    for (var i = 0; i < 3; i++) {
      world.addFixture(value: 1, x: 30 + i * 6.8, y: 100);
    }
    world.advance(MergeWorld.fixedStep);
    expect(world.balls.map((b) => b.value).toList()..sort(), [1, 2]);
    expect(world.score, 2);
    expect(world.balls.map((b) => b.id).toSet().length, world.balls.length);
  });
  test('chain merges continue on a later physics step', () {
    final world = MergeWorld();
    world.addFixture(value: 1, x: 30, y: 100);
    world.addFixture(value: 1, x: 36.8, y: 100);
    world.addFixture(value: 2, x: 33.4, y: 92.5);
    simulate(world, 1);
    expect(world.balls, hasLength(1));
    expect(world.balls.single.value, 4);
    expect(world.score, 6);
  });
  test(
    'balls fall, collide with the floor and stack without passing through',
    () {
      final world = MergeWorld();
      world.addFixture(value: 6, x: 50, y: 120);
      world.addFixture(value: 7, x: 50, y: 75);
      simulate(world, 8);
      expect(world.balls, hasLength(2));
      final low = world.balls.first, high = world.balls.last;
      expect(low.y + low.radius, closeTo(MergeWorld.height, .1));
      expect(
        (low.y - high.y).abs(),
        greaterThanOrEqualTo(low.radius + high.radius - .15),
      );
      expect(low.settled, isTrue);
      expect(high.settled, isTrue);
    },
  );
  test('new falling balls do not trigger overflow; settled stacks get a grace period', () {
    final falling = MergeWorld(random: math.Random(2));
    falling.drop(50);
    simulate(falling, .5);
    expect(falling.gameOver, isFalse);
    final stack = MergeWorld();
    final r = MergeWorld.radiusFor(6);
    for (var i = 0; i < 9; i++) {
      stack.addFixture(value: 6, x: 50, y: MergeWorld.height - r - i * 2 * r);
    }
    simulate(stack, 1);
    expect(stack.gameOver, isFalse);
    simulate(stack, 8);
    expect(stack.gameOver, isTrue);
  });
  test(
    'pause and restart freeze/reset simulation; previews only roll 1 through 5',
    () {
      final world = MergeWorld(random: math.Random(42));
      for (var i = 0; i < 100; i++) {
        expect(world.nextValue, inInclusiveRange(1, 5));
        world.restart();
      }
      world.drop(1);
      final y = world.balls.single.y;
      world.paused = true;
      simulate(world, 2);
      expect(world.balls.single.y, y);
      expect(world.drop(70), isFalse);
      world.restart();
      expect(world.balls, isEmpty);
      expect(world.score, 0);
      expect(world.gameOver, isFalse);
      expect(world.canDrop, isTrue);
    },
  );
  test('rendered radii strictly increase with value; wall clamps and overlap remain finite', () {
    for (var i = 1; i < 10; i++) {
      expect(MergeWorld.radiusFor(i + 1), greaterThan(MergeWorld.radiusFor(i)));
    }
    final world = MergeWorld();
    world.drop(-100);
    simulate(world, 1);
    for (final b in world.balls) {
      expect(b.x, greaterThanOrEqualTo(b.radius));
      expect(b.y.isFinite, isTrue);
    }
    world.addFixture(value: 5, x: 50, y: 120);
    world.addFixture(value: 5, x: 50, y: 120);
    simulate(world, 3);
    for (final b in world.balls) {
      expect(b.x.isFinite && b.y.isFinite, isTrue);
      expect(b.x, inInclusiveRange(b.radius, 100 - b.radius));
      expect(b.y + b.radius, lessThanOrEqualTo(140.01));
    }
  });
}
