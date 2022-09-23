import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hello_package/demo/impl/animation.dart';
import 'package:hello_package/demo/impl/preempt_point.dart';

void main() {
  debugPrintBeginFrameBanner = debugPrintEndFrameBanner = true;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Mode? mode;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          _buildFirstPage(),
          EnterPageAnimation(
            mode: mode,
            child: _buildSecondPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstPage() {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Preempt for 60FPS')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final targetMode in Mode.values)
                TextButton(
                  onPressed: () => setState(() => mode = targetMode),
                  child: Text('mode=${targetMode.name}'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondPage() {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SecondPage'),
          leading: IconButton(
            onPressed: () => setState(() => mode = null),
            icon: const Icon(Icons.arrow_back_ios),
          ),
        ),
        body: const ComplexWidget(),
      ),
    );
  }
}

class ComplexWidget extends StatelessWidget {
  const ComplexWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // @dnfield's suggestion - a lot of text
    // https://github.com/flutter/flutter/issues/101227#issuecomment-1247641562
    return Material(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Column(
          children: List<Widget>.generate(30, (int index) {
            return SizedBox(
              height: 24,
              // NOTE hack, in real world should auto have preempt point
              // but in prototype we do it by hand
              child: PreemptPoint(
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircleAvatar(
                      child: Text('G$index'),
                    ),
                  ),
                  title: Text(
                    'Foo contact from $index-th local contact' * 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 5),
                  ),
                  subtitle: Text('+91 88888 8800$index'),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
