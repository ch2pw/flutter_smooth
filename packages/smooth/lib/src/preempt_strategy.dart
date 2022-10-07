import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:smooth/src/binding.dart';
import 'package:smooth/src/constant.dart';
import 'package:smooth/src/simple_date_time.dart';

abstract class PreemptStrategy {
  factory PreemptStrategy.normal() = PreemptStrategyNormal;

  const factory PreemptStrategy.never() = _PreemptStrategyNever;

  /// Should we run `preemptRender` now
  bool shouldAct({Object? debugToken});

  /// returns act smoothFrameTimeStamp
  Duration? shouldActAtEndOfDrawFrame();

  /// Fancy version of [SchedulerBinding.currentFrameTimeStamp],
  /// by considering both plain-old frames and *also extra frames*
  Duration get currentSmoothFrameTimeStamp;

  /// Be called when `preemptRender` is run
  void refresh();
}

class PreemptStrategyDependency {
  const PreemptStrategyDependency();

  SimpleDateTime now() => clock.nowSimple();

  Duration get currentFrameTimeStamp =>
      SmoothSchedulerBindingMixin.instance.currentFrameTimeStamp;

  DateTime get beginFrameDateTime =>
      SmoothSchedulerBindingMixin.instance.beginFrameDateTime;
}

@visibleForTesting
class PreemptStrategyNormal implements PreemptStrategy {
  final PreemptStrategyDependency dependency;
  final TimeInfoCalculator timeInfoCalculator;

  /// the VsyncTargetTime used by last preempt render
  var _currentPreemptRenderVsyncTargetTimeStamp =
      const Duration(seconds: -10000);

  PreemptStrategyNormal({
    this.dependency = const PreemptStrategyDependency(),
  }) : timeInfoCalculator = TimeInfoCalculator(dependency);

  @override
  bool shouldAct({Object? debugToken}) {
    final now = dependency.now();
    final nowTimeStamp = timeInfoCalculator.dateTimeToTimeStamp(now);
    final ans = nowTimeStamp > shouldActTimeStamp;

    // if (ans) {
    //   // this "latency" is an important (?) indicator 36020 #6021
    //   final latency = nowTimeStamp - shouldActTimeStamp;
    //   print('$runtimeType.shouldAct=true latency=$latency');
    //   //   print(
    //   //     'shouldAct=true '
    //   //     'now=$now nowTimeStamp=$nowTimeStamp '
    //   //     'shouldActTimeStamp=$shouldActTimeStamp '
    //   //     'currentSmoothFrameTimeStamp=$currentSmoothFrameTimeStamp '
    //   //     'currentFrameAdjustedVsyncTargetTimeStamp=${_timeInfoCalculator.currentFrameAdjustedVsyncTargetTimeStamp} '
    //   //     'currentPreemptRenderVsyncTargetTimeStamp=$_currentPreemptRenderVsyncTargetTimeStamp',
    //   //   );
    // }

    return ans;
  }

  @override
  Duration? shouldActAtEndOfDrawFrame() {
    // the one refreshed by AfterLayout
    final prevSmoothFrameTimeStamp = currentSmoothFrameTimeStamp;
    final now = dependency.now();
    final nowTimeStamp = timeInfoCalculator.dateTimeToTimeStamp(now);
    // see #6042, and logical thinking...
    final shouldPreemptRender = prevSmoothFrameTimeStamp < nowTimeStamp;
    if (!shouldPreemptRender) return null;

    // indeed, `preemptStrategy.refresh()` will not give what we want...
    final smoothFrameTimeStamp = prevSmoothFrameTimeStamp + kOneFrame;
    return smoothFrameTimeStamp;
  }

  // this threshold is not sensitive. see design doc.
  static const kActThresh = Duration(milliseconds: 2);

  Duration get shouldActTimeStamp {
    final nextActVsyncTimeStamp = _maxDuration(
      timeInfoCalculator.currentFrameAdjustedVsyncTargetTimeStamp,
      _currentPreemptRenderVsyncTargetTimeStamp + kOneFrame,
    );
    return nextActVsyncTimeStamp - kActThresh;
  }

  @override
  Duration get currentSmoothFrameTimeStamp {
    return _maxDuration(
      timeInfoCalculator.currentFrameAdjustedVsyncTargetTimeStamp,
      _currentPreemptRenderVsyncTargetTimeStamp,
    );
  }

  @override
  void refresh() {
    final now = dependency.now();
    final nowTimeStamp = timeInfoCalculator.dateTimeToTimeStamp(now);

    final nextVsync = vsyncLaterThan(
      time: nowTimeStamp,
      baseVsync: timeInfoCalculator.currentFrameAdjustedVsyncTargetTimeStamp,
    );

    final shouldShiftOneFrame =
        nextVsync - nowTimeStamp > const Duration(milliseconds: 12);

    _currentPreemptRenderVsyncTargetTimeStamp =
        nextVsync - (shouldShiftOneFrame ? kOneFrame : Duration.zero);
  }

  @visibleForTesting
  static Duration vsyncLaterThan({
    required Duration time,
    required Duration baseVsync,
  }) {
    final diffMicroseconds = time.inMicroseconds - baseVsync.inMicroseconds;
    return baseVsync +
        Duration(
          microseconds: (diffMicroseconds / kOneFrameUs).ceil() * kOneFrameUs,
        );
  }
}

Duration _maxDuration(Duration a, Duration b) => a > b ? a : b;

class TimeInfoCalculator {
  final PreemptStrategyDependency dependency;

  const TimeInfoCalculator(this.dependency);

  /// The adjusted VsyncTargetTime for current plain-old frame
  /// "adjust" means [SchedulerBinding._adjustForEpoch]
  Duration get currentFrameAdjustedVsyncTargetTimeStamp {
    // we can obtain current plain-old frame's VsyncTargetTime
    // easily because it is exposed as follows by looking at source code:
    // 1. [currentSystemFrameTimeStamp] is VsyncTargetTime
    // 2. [currentFrameTimeStamp] is the adjusted [currentSystemFrameTimeStamp]
    // 3. [currentFrameTimeStamp] is provided to animation callbacks
    return dependency.currentFrameTimeStamp;
  }

  /// Converting between a [DateTime] (representing real-world time)
  /// and an "adjusted TimeStamp" such as [SchedulerBinding.currentFrameTimeStamp]
  int get diffDateTimeToTimeStamp =>
      _currentFrameVsyncTargetDateTime.microsecondsSinceEpoch -
      currentFrameAdjustedVsyncTargetTimeStamp.inMicroseconds;

  // we need to *add one frame*, because [(adjusted) VsyncTargetTime] means
  // the end of current plain-old frame, while [beginFrameDateTime] means
  // the clock when plain-old frame starts.
  DateTime get _currentFrameVsyncTargetDateTime =>
      // NOTE this add one frame
      dependency.beginFrameDateTime.add(kOneFrame);

  // SimpleDateTime timeStampToDateTime(Duration timeStamp) =>
  //     SimpleDateTime.fromMicrosecondsSinceEpoch(
  //         timeStamp.inMicroseconds + diffDateTimeToTimeStamp);

  Duration dateTimeToTimeStamp(SimpleDateTime dateTime) => Duration(
      microseconds: dateTime.microsecondsSinceEpoch - diffDateTimeToTimeStamp);
}

class _PreemptStrategyNever implements PreemptStrategy {
  const _PreemptStrategyNever();

  @override
  bool shouldAct({Object? debugToken}) => false;

  @override
  Duration? shouldActAtEndOfDrawFrame() => null;

  @override
  void refresh() {}

  @override
  Duration get currentSmoothFrameTimeStamp =>
      SchedulerBinding.instance.currentFrameTimeStamp;
}
