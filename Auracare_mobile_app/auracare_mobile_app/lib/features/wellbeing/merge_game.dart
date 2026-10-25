import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';
import 'merge_world.dart';
import 'ball_face.dart';

class MergeGamePage extends StatefulWidget {
  const MergeGamePage({super.key});
  @override
  State<MergeGamePage> createState() => _MergeGamePageState();
}

class _MergeGamePageState extends State<MergeGamePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  final world = MergeWorld();
  late final Ticker ticker;
  Duration? lastTick;
  ModalRoute<dynamic>? observedRoute;
  double aim = 50;
  bool sliderGesture = false;
  bool boardGesture = false;
  void finishBoardGesture() {
    final intentional = boardGesture;
    boardGesture = false;
    if (intentional) drop();
  }

  double clampAim(double value) {
    final r = MergeWorld.radiusFor(world.nextValue);
    return value.clamp(r, MergeWorld.width - r);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker(tick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != observedRoute) {
      auraRouteObserver.unsubscribe(this);
      observedRoute = route;
      if (route != null) auraRouteObserver.subscribe(this, route);
    }
  }

  void tick(Duration elapsed) {
    final previous = lastTick;
    lastTick = elapsed;
    if (previous == null) return;
    world.advance((elapsed - previous).inMicroseconds / 1000000);
    if (world.gameOver) {
      ticker.stop();
      lastTick = null;
    }
    if (mounted) setState(() {});
  }

  void pause() {
    sliderGesture = false;
    boardGesture = false;
    world.paused = true;
    ticker.stop();
    lastTick = null;
    if (mounted) setState(() {});
  }

  void resume() {
    if (world.gameOver) return;
    world.paused = false;
    lastTick = null;
    if (!ticker.isActive) ticker.start();
    setState(() {});
  }

  @override
  void didPushNext() => pause();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  @override
  void deactivate() {
    world.paused = true;
    ticker.stop();
    lastTick = null;
    super.deactivate();
  }

  @override
  void dispose() {
    auraRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    super.dispose();
  }

  void drop() {
    if (world.drop(aim)) setState(() => aim = clampAim(aim));
  }

  Future<void> restart() async {
    pause();
    if (await confirm(
      context,
      'Restart round?',
      'Your current score will be cleared.',
      action: 'Restart',
    )) {
      if (!mounted) return;
      world.restart();
      resume();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Merge & Unwind'),
      actions: [
        IconButton(
          tooltip: world.paused ? 'Resume game' : 'Pause game',
          onPressed: world.gameOver
              ? null
              : world.paused
              ? resume
              : pause,
          icon: Icon(
            world.paused ? Icons.play_arrow_outlined : Icons.pause_outlined,
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: spaced([
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                'Score: ${world.score}',
                key: const ValueKey('merge-score'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Next ball: ${ballName(world.nextValue)}',
                key: const ValueKey('merge-next'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Text(
            'Match the same color to merge. Green becomes turquoise, then pink, then purple. Each merge adds to your score. Larger pairs that reach the size limit stay separate.',
          ),
          Semantics(
            label:
                'Game container. ${world.balls.length} balls. Overflow line near the top.',
            child: LayoutBuilder(
              builder: (context, constraints) => AspectRatio(
                aspectRatio: MergeWorld.width / MergeWorld.height,
                child: GestureDetector(
                  key: const ValueKey('merge-board'),
                  onTapDown: (d) {
                    boardGesture = world.canDrop;
                    if (world.canDrop) {
                      setState(
                        () => aim =
                            (d.localPosition.dx / constraints.maxWidth * 100)
                                .clamp(
                                  MergeWorld.radiusFor(world.nextValue),
                                  100 - MergeWorld.radiusFor(world.nextValue),
                                ),
                      );
                    }
                  },
                  onTapUp: (_) => finishBoardGesture(),
                  onTapCancel: () => boardGesture = false,
                  onPanStart: (d) {
                    boardGesture = world.canDrop;
                    if (boardGesture) {
                      setState(
                        () => aim = clampAim(
                          d.localPosition.dx / constraints.maxWidth * 100,
                        ),
                      );
                    }
                  },
                  onPanCancel: () => boardGesture = false,
                  onPanUpdate: (d) {
                    if (world.canDrop) {
                      setState(
                        () => aim =
                            (d.localPosition.dx / constraints.maxWidth * 100)
                                .clamp(
                                  MergeWorld.radiusFor(world.nextValue),
                                  100 - MergeWorld.radiusFor(world.nextValue),
                                ),
                      );
                    }
                  },
                  onPanEnd: (_) => finishBoardGesture(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(
                      painter: _WorldPainter(
                        world,
                        aim,
                        MediaQuery.disableAnimationsOf(context),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            world.gameOver
                ? 'Round complete'
                : world.paused
                ? 'Paused'
                : 'Tap or drag to choose a drop position.',
            key: const ValueKey('merge-status'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (world.gameOver)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaced([
                  const Text(
                    'The container is full. Take a breath and play again whenever you like.',
                  ),
                  FilledButton(
                    onPressed: () {
                      world.restart();
                      resume();
                    },
                    child: const Text('Play Again'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ]),
              ),
            )
          else ...[
            Semantics(
              label: 'Horizontal drop position',
              child: Slider(
                value: aim,
                min: 0,
                max: 100,
                onChangeStart: world.canDrop
                    ? (_) => sliderGesture = true
                    : null,
                onChangeEnd: (_) {
                  final intentional = sliderGesture;
                  sliderGesture = false;
                  if (intentional) drop();
                },
                onChanged: world.canDrop
                    ? (v) => setState(() => aim = clampAim(v))
                    : null,
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: world.canDrop ? drop : null,
                  child: const Text('Drop ball'),
                ),
                OutlinedButton(
                  onPressed: world.paused ? resume : pause,
                  child: Text(world.paused ? 'Resume' : 'Pause'),
                ),
                TextButton(onPressed: restart, child: const Text('Restart')),
              ],
            ),
          ],
          const Text(
            'Sound is off. This round is not saved. Settled balls above the line end the round after a short grace period.',
          ),
        ]),
      ),
    ),
  );
}

class _WorldPainter extends CustomPainter {
  const _WorldPainter(this.world, this.aim, this.reducedMotion);
  final bool reducedMotion;
  final MergeWorld world;
  final double aim;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / MergeWorld.width,
      size.height / MergeWorld.height,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, MergeWorld.width, MergeWorld.height),
      Paint()..color = Palette.mist,
    );
    final line = Paint()
      ..color = Palette.plum
      ..strokeWidth = .5;
    canvas.drawLine(
      const Offset(0, 0),
      const Offset(0, MergeWorld.height),
      line,
    );
    canvas.drawLine(
      const Offset(MergeWorld.width, 0),
      const Offset(MergeWorld.width, MergeWorld.height),
      line,
    );
    canvas.drawLine(
      const Offset(0, MergeWorld.height - .3),
      const Offset(MergeWorld.width, MergeWorld.height - .3),
      line,
    );
    for (var x = 2.0; x < MergeWorld.width; x += 5) {
      canvas.drawLine(
        Offset(x, MergeWorld.overflowLine),
        Offset(x + 2, MergeWorld.overflowLine),
        line,
      );
    }
    void ball(
      int value,
      double x,
      double y, {
      bool preview = false,
      double age = 1,
    }) {
      final radius = MergeWorld.radiusFor(value);
      canvas.save();
      canvas.translate(x, y);
      if (!reducedMotion && !preview && age < .22) {
        canvas.scale(1 + .10 * (1 - age / .22));
      }
      paintBallFace(canvas, value, radius);
      canvas.restore();
    }

    if (!world.gameOver) {
      final r = MergeWorld.radiusFor(world.nextValue);
      ball(
        world.nextValue,
        aim.clamp(r, MergeWorld.width - r),
        r + 1,
        preview: true,
      );
    }
    for (final b in world.balls) {
      ball(b.value, b.x, b.y, age: b.age);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WorldPainter oldDelegate) => true;
}
