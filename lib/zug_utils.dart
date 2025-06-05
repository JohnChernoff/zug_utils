library zug_utils;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ini/ini.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

enum ZugEnum { unknown }

class ScreenDim {
  final double width,height;
  ScreenDim(this.width,this.height);
  Axis getMainAxis() {
    return width > height ? Axis.horizontal : Axis.vertical;
  }
}

class ZugUtils {
  static Future<Config> getIniConfig(String assetPath) {
    return rootBundle.loadString(assetPath).then((value) => Config.fromString(value));
  }

  static Future<Map<String,String>> getIniDefaults(String assetPath) {
    return rootBundle.loadString(assetPath)
        .then((value) => Config.fromString(value), onError: (argh) => Config.fromString(""))
        .then((config) => config.defaults());
  }

  static double getActualScreenHeight(BuildContext context) { //rename to approxScreenHeight?
    return MediaQuery.of(context).size.height - (AppBar().preferredSize.height + kBottomNavigationBarHeight) - 8;
  }

  static ScreenDim getScreenDimensions(BuildContext context) {
    return ScreenDim(MediaQuery.of(context).size.width,getActualScreenHeight(context));
  }

  static bool isLandscape(BoxConstraints constraints) {
    return constraints.maxWidth > constraints.maxHeight;
  }

  static double roundNumber(double value, int places) {
    num val = pow(10.0, places);
    return ((value * val).round().toDouble() / val);
  }

  static scrollDown(ScrollController scrollController, int millis, {int delay = 0}) {
    Future.delayed(Duration(milliseconds: delay)).then((value) {
      if (scrollController.hasClients) { //in case user switched away
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          curve: Curves.easeOut,
          duration: Duration(milliseconds: millis),
        );
      }
    });
  }

  static AssetImage getAssetImage(String path) {
    return AssetImage("${(kDebugMode && kIsWeb)?"":"assets/"}$path");
  }

  static Future<void> launch(String url, {bool isNewTab = true}) async {
    await launchUrl(
      Uri.parse(url),
      webOnlyWindowName: isNewTab ? '_blank' : '_self',
    );
  }

  static Future<String?> getIP() async {
    try {
      if (kIsWeb) {
        var response =
        await http.get(Uri(scheme: "https", host: 'api.ipify.org'));
        if (response.statusCode == 200) {
          //ZugClient.log.fine(response.body);
          return response.body;
        } else {
          //ZugClient.log.info(response.body);
          return null;
        }
      } else {
        List<NetworkInterface> list = await NetworkInterface.list();
        return list.first.addresses.first.address;
      }
    } catch (exception) {
      //ZugClient.log.info(exception);
      return null;
    }
  }

  static Future<SharedPreferences?> getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  static int getMaxSizeOfSquaresInRect(double width, double height, int tileCount) {
    if (width * height < tileCount) {
      return 0;
    } // quick bailout for invalid input
    // come up with an initial guess
    double aspect = height / width;
    double xf = sqrt(tileCount / aspect);
    double yf = xf * aspect;
    int x = max(1, xf.floor());
    int y = max(1, yf.floor());
    int xSize = (width / x).floor();
    int ySize = (height / y).floor();
    int tileSize = min(xSize, ySize);
    // test our guess:
    x = (width / tileSize).floor();
    y = (height / tileSize).floor();
    if ((x * y) < tileCount) {
      // we guessed too high
      if (((x + 1) * y < tileCount) && (x * (y + 1) < tileCount)) {
        // case 2: the upper bound is correct, compute the tileSize that will result in (x+1)*(y+1) tiles
        xSize = (width / (x + 1)).floor();
        ySize = (height / (y + 1)).floor();
        tileSize = min(xSize, ySize);
      } else {
        // case 3: solve an equation to determine the final x and y dimensions and then compute the tileSize that results in those dimensions
        int testX = (tileCount / y).ceil();
        int testY = (tileCount / x).ceil();
        xSize = min((width / testX).floor(), (height / y).floor());
        ySize = min((width / x).floor(), (height / testY).floor());
        tileSize = max(xSize, ySize);
      }
    }
    return tileSize;
  }

  static int getMaxSizeOfSpacedSquaresInRect(double width, double height, int tileCount, double spacing) {
    if (width * height < tileCount) {
      return 0;
    }

    // Assume grid with x columns and y rows:
    // Total width used: x * tileSize + (x - 1) * spacing <= width
    // Total height used: y * tileSize + (y - 1) * spacing <= height
    // with y = ceil(tileCount / x)

    int bestTileSize = 0;
    for (int cols = 1; cols <= tileCount; cols++) {
      int rows = (tileCount / cols).ceil();
      double tileWidth = (width - (cols - 1) * spacing) / cols;
      double tileHeight = (height - (rows - 1) * spacing) / rows;
      int tileSize = tileWidth.floor().clamp(0, tileHeight.floor());
      if (tileSize > bestTileSize) {
        bestTileSize = tileSize;
      }
    }

    return bestTileSize;
  }

  static Future<ui.Image> imageToUI(Image image) {
    Completer<ui.Image> completer = Completer<ui.Image>();
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
        ImageStreamListener(
                (ImageInfo info, bool _) => completer.complete(info.image)));
    return completer.future;
  }

  static Future<img.Image> uImageToImgPkg(ui.Image image) async {
    final bytes = await image.toByteData();
    return img.Image.fromBytes(width: image.width, height: image.height, bytes: bytes!.buffer, order: img.ChannelOrder.rgba);
  }

  static Future<img.Image> imageToImgPkg(Image image) async {
    return uImageToImgPkg(await imageToUI(image));
  }

}

mixin Timerable {
  int? startTime;
  int? duration;
  int? inc;

  void setTimer(int dur, int i) {
    startTime = DateTime.now().millisecondsSinceEpoch; duration = dur; inc = i;
  }
}

abstract class TimedWidget extends StatefulWidget {
  final Timerable source;
  const TimedWidget(this.source,{super.key});
}

abstract class TimedWidgetState extends State<TimedWidget> {
  int timeRemaining = 0;
  int tick = 0;
  bool finished = false;
  int startTime = 0;

  @override
  void initState() {
    super.initState();
    setTimer();
    //ZugClient.log.fine("Initializing TimedWidget: ${widget.source.duration}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _countdownLoop();
    });
  }

  void setTimer() {
    startTime = widget.source.startTime ?? 0;
    timeRemaining = (widget.source.duration ?? 0) - getElapsedTime();
  }

  void updateTimer() {
    setState(() {
      timeRemaining -= (widget.source.inc ?? 0);
      tick++;
    });
  }

  int getElapsedTime() {
    return DateTime.now().millisecondsSinceEpoch - (widget.source.startTime ?? 0);
  }

  double getPercentDone() {
    return widget.source.duration != 0 ? getElapsedTime() / (widget.source.duration ?? 1) : 0;
  }

  void _countdownLoop() async {
    WidgetsFlutterBinding.ensureInitialized();
    //ZugClient.log.fine("Starting countdown");
    while (!finished) {
      await Future.delayed(Duration(milliseconds: widget.source.inc ?? 0), () {
        if (mounted && timeRemaining > 0) {
          if (startTime != widget.source.startTime) {
            setTimer();
          } else {
            updateTimer();
          }
        }
        else {
          finished = true;
        }
      });
    }
    //ZugClient.log.fine("Ending countdown");
  }

}

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String? hexString, {Color defaultColor = Colors.white}) {
    if (hexString == null) return defaultColor;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static Color rndColor({pastel = false}) {
    if (pastel) {
      return Color.fromRGBO(
          Random().nextInt(128) + 128,
          Random().nextInt(128) + 128,
          Random().nextInt(128) + 128, 1.0);
    }
    else {
      return Color((Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
    }
  }



  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}

/*
  static double erp(int n,double w, double h) {
    double sw,sh;
    int pw = sqrt(n * (w / h)).ceil();
    if ((pw * (h/w).floor()) * pw < n) {
      sw = h/((pw * (h/w))).ceil();
    } else {
      sw = w/pw;
    }
    int ph = sqrt(n * (h / w)).ceil();
    if ((ph * (w/h).floor()) * ph < n) {
      sh = w/((w * (ph/h))).ceil();
    }
    else {
      sh = h/ph;
    }
    return max(sw,sh);
  }
 */