import 'dart:developer';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

class PointsModel extends ChangeNotifier {
  List<Offset> points = [];

  void addPoint(Offset point) {
    points.add(point);
    notifyListeners();
  }

  void clear() {
    points.clear();
    notifyListeners();
  }
}

class CurrentLabelModel extends ChangeNotifier {
  String currentLabel = "True";

  void toggle() {
    (currentLabel == "True") ? currentLabel = "False" : currentLabel = "True";
    notifyListeners();
  }
}

List trace = [];
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
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PointsModel()),
        ChangeNotifierProvider(create: (context) => CurrentLabelModel())
      ],
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
            leading: Builder(builder: (context) {
              return CupertinoButton(
                sizeStyle: CupertinoButtonSize.small,
                child: Icon(
                  CupertinoIcons.settings,
                  size: 24,
                ),
                onPressed: () => _showPopupSurface(context),
              );
            }),
            middle: Text("Signature Collector"),
            trailing: Consumer<PointsModel>(
              builder: (context, value, child) {
                return CupertinoButton(
                  sizeStyle: CupertinoButtonSize.small,
                  onPressed: (value.points.isEmpty) ? null : () => saveTrace(context),
                  child: Icon(
                    CupertinoIcons.check_mark,
                    size: 24,
                  ),
                );
              },
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
        trace.addAll([
          details.globalPosition.dx,
          details.globalPosition.dy,
          (DateTime.now().difference(startedDrawing!).inMicroseconds)
        ]);
      }
    },
    onPanEnd: (_) {
      Provider.of<PointsModel>(context, listen: false).addPoint(Offset.zero);
      // print(trace.join(","));
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

Future<void> _showPopupSurface(BuildContext context) async {
  Directory dir = await getApplicationDocumentsDirectory();
  File yFile = File("${dir.path}/y.txt");
  int trueCount = 0, falseCount = 0;
  if (await yFile.exists()) {
    trueCount = (await yFile.readAsLines()).where((element) => element == "1").length;
    falseCount = (await yFile.readAsLines()).length - trueCount;
  }

  if (context.mounted) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoPopupSurface(
          isSurfacePainted: false,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: <Widget>[
                Expanded(child: Container()),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    children: [
                      CupertinoListTile.notched(
                        title: Text("Current Label"),
                        trailing: CupertinoButton(
                            onPressed: () {
                              Provider.of<CurrentLabelModel>(context, listen: false).toggle();
                            },
                            child: Consumer<CurrentLabelModel>(builder: (context, value, child) => Text(value.currentLabel))),
                      ),
                      CupertinoListTile.notched(
                        title: Text("Data Collected (T, F)"),
                        trailing: Text("($trueCount, $falseCount)"),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: CupertinoColors.white,
                    onPressed: () {
                      clearCanvas(context);
                      Navigator.pop(context);
                    },
                    child: const Text('Clear the canvas', style: TextStyle(color: CupertinoColors.systemBlue)),
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: CupertinoColors.white,
                    onPressed: () async {
                      const MethodChannel mc = MethodChannel("com.example.save_to_downloads");
                      bool resultY = await mc.invokeMethod("saveToDownloads", {
                        "content": await yFile.readAsString(),
                        "fileName": "signaturecollectorY.txt",
                        "mimeType": "text/plain"
                      });

                      File xFile = File("${dir.path}/X.txt");
                      bool resultX = await mc.invokeMethod("saveToDownloads", {
                        "content": await xFile.readAsString(),
                        "fileName": "signaturecollectorX.txt",
                        "mimeType": "text/plain"
                      });

                      debugger();
                      // Navigator.pop(context);
                    },
                    child: const Text('Export data', style: TextStyle(color: CupertinoColors.systemBlue)),
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: CupertinoColors.white,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: CupertinoColors.systemBlue)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> saveTrace(BuildContext context) async {
  Directory dir = await getApplicationDocumentsDirectory();

  File xFile = File("${dir.path}/X.txt");
  await xFile.writeAsString('${trace.join(",")}\n', mode: FileMode.append);

  File yFile = File("${dir.path}/y.txt");
  late String labelValue;
  if (context.mounted && Provider.of<CurrentLabelModel>(context, listen: false).currentLabel == "True") {
    labelValue = "1";
  } else {
    labelValue = "0";
  }
  await yFile.writeAsString("$labelValue\n", mode: FileMode.append);

  if (context.mounted) clearCanvas(context);
}

void clearCanvas(BuildContext context) {
  Provider.of<PointsModel>(context, listen: false).clear();
  trace.clear();
}
