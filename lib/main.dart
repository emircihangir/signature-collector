import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class PointsModel extends ChangeNotifier {
  List<Offset> points = [];

  void addPoint(Offset point) {
    points.add(point);
    notifyListeners();
  }
}

List<List> trace = [];
DateTime? startedDrawing;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp
  ]);

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: CupertinoColors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: CupertinoColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(
    ChangeNotifierProvider(
      create: (context) => PointsModel(),
      builder: (context, child) => SignatureCollectorApp(),
    ),
  );
}

class SignatureCollectorApp extends StatelessWidget {
  const SignatureCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            leading: CupertinoButton(
              sizeStyle: CupertinoButtonSize.small,
              child: Icon(
                CupertinoIcons.settings,
                size: 24,
              ),
              onPressed: () {},
            ),
            middle: Text("Signature Collector"),
            trailing: CupertinoButton(
              sizeStyle: CupertinoButtonSize.small,
              child: Icon(
                CupertinoIcons.check_mark,
                size: 24,
              ),
              onPressed: () {},
            ),
          ),
          child: whiteBoard(context)),
    );
  }
}

Widget whiteBoard(BuildContext context) {
  return GestureDetector(
    onPanUpdate: (details) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      Offset point = renderBox.globalToLocal(details.globalPosition);

      Provider.of<PointsModel>(context, listen: false).addPoint(point);

      if (startedDrawing == null) {
        startedDrawing = DateTime.now();
      } else {
        trace.add([
          details.globalPosition.dx,
          details.globalPosition.dy,
          (DateTime.now().difference(startedDrawing!).inMicroseconds)
        ]);
      }
    },
    onPanEnd: (_) {
      Provider.of<PointsModel>(context, listen: false).addPoint(Offset.zero);
    },
    child: Consumer<PointsModel>(
      builder: (context, value, child) {
        return CustomPaint(
          painter: WhiteboardPainter(value.points),
          size: Size.infinite,
        );
      },
    ),
  );
}

class WhiteboardPainter extends CustomPainter {
  final List<Offset> points;

  WhiteboardPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CupertinoColors.black
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(WhiteboardPainter oldDelegate) => true;
}
