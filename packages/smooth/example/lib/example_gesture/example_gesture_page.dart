import 'package:example/example_gesture/gesture_visualizer.dart';
import 'package:example/utils/complex_widget.dart';
import 'package:example/utils/debug_plain_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:smooth/smooth.dart';

class ExampleGesturePage extends StatelessWidget {
  const ExampleGesturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            const RepaintBoundary(
              child: CounterWidget(prefix: 'Plain: '),
            ),
            SizedBox(
              height: 200,
              child: SmoothBuilder(
                builder: (_, child) => Directionality(
                  textDirection: TextDirection.ltr,
                  child: GestureVisualizerByListener(
                    child: Stack(
                      children: [
                        Positioned.fill(
                            child: ColoredBox(color: Colors.blue.shade50)),
                        const CounterWidget(prefix: 'Smooth: '),
                      ],
                    ),
                  ),
                ),
                // child: Container(color: Colors.green),
                child: const SizedBox(),
              ),
            ),
            SizedBox(
              height: 100,
              // https://github.com/fzyzcjy/yplusplus/issues/5876#issuecomment-1263264848
              child: RepaintBoundary(
                // https://github.com/fzyzcjy/yplusplus/issues/5876#issuecomment-1263276032
                child: ClipRect(
                  child: OverflowBox(
                    child: _buildAlwaysRebuildComplexWidget(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static var _dummy = 1;

  Widget _buildAlwaysRebuildComplexWidget() {
    return StatefulBuilder(builder: (_, setState) {
      SchedulerBinding.instance.addPostFrameCallback((_) => setState(() {}));

      return ComplexWidget(
        // thus it will recreate the whole subtree, in each frame
        key: ValueKey('${_dummy++}'),
        // listTileCount: 150,
        // TODO temporary, only for #5879 reproduction
        listTileCount: 2,
        wrapListTile: null,
      );
    });
  }
}
