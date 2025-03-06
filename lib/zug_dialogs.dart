import 'dart:collection';
import 'package:flutter/material.dart';

class DialogListener<T> extends StatefulWidget {
  const DialogListener({
    required this.builder,
    required this.listenable,
    required this.listener,
    super.key,
  });

  final ValueNotifier<T> listenable;
  final void Function(T previous, T next) listener;
  final WidgetBuilder builder;

  @override
  State<DialogListener<T>> createState() => _DialogListenerState<T>();
}

class _DialogListenerState<S> extends State<DialogListener<S>> {
  late S previous;
  @override
  void initState() {
    super.initState();
    previous = widget.listenable.value;
    widget.listenable.addListener(listener);
  }
  void listener() {
    final value = widget.listenable.value;
    widget.listener(previous, value);
    previous = value;
  }
  @override
  void dispose() {
    widget.listenable.removeListener(listener);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}

class ZugDialogs {

  static GlobalKey<NavigatorState>? _navigatorKey;
  static Set<BuildContext> currentContexts = HashSet();

  ZugDialogs();

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static void popDialog<T extends Object>(BuildContext ctx, [T? result]) {
    Navigator.pop(ctx,result);
    currentContexts.remove(ctx);
  }

  static void clearDialogs() {
    for (BuildContext ctx in ZugDialogs.currentContexts) {
      popDialog(ctx);
    }
    ZugDialogs.currentContexts.clear(); //shouldn't be necessary
  }

  static Future<bool> popup(String txt, { String imgFile = "" } ) async {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return false;
    currentContexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Center(
              child: NotificationDialog(txt, imageFilename: imgFile));
        }).then((ok)  {
      return ok ?? false;
    });
  }

  static Future<bool> confirm(String txt, { ValueNotifier<bool?>? canceller, String imgFile = "" } ) async {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return false;
    currentContexts.add(ctx);
    return showDialog(
        barrierDismissible: false,
        context: ctx,
        builder: (BuildContext context) {
          Widget dialog = ConfirmDialog(txt, imageFilename: imgFile);
          return Center(
              child: canceller != null ? CancellableDialog(dialog,canceller) : dialog);
        }).then((ok)  {
      return ok ?? false;
    });
  }

  static Future<dynamic> getValue(ValueDialog valueDialog) async {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return "";
    currentContexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Center(child: valueDialog);
        }).then((value) {
      return value ?? "";
    });
  }

  static Future<String> getString(String prompt,String defTxt) async {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return "";
    ZugDialogs.currentContexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Center(child: TextDialog(prompt, defTxt));
        }).then((value) {
      return value ?? "";
    });
  }

  static Future<int> getIcon(String prompt, List<Icon> iconList) async {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return 0;
    currentContexts.add(ctx); //TODO: does this do anything?
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Center(child: IconSelectDialog(prompt, iconList));
        }).then((value) {
      return value ?? 0;
    });
  }

  static Future<dynamic> getItem(String prompt, List<dynamic> itemList, List<String> fieldList, String actionString, {double sizeFactor = 1} ) async {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return 0;
    currentContexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Center(child: ItemSelectDialog(itemList,fieldList, actionString, sizeFactor: sizeFactor));
        }).then((item) {
      return item ?? {};
    });
  }

  static Future<Widget?> getWidget(String prompt, List<Widget> widgetList, int axisCount,
      {bool showTime = false, int seconds = 0, Offset sizeFactor = const Offset(1,1), Alignment alignment = Alignment.center, Color color = Colors.white, Color backgroundColor = Colors.black}) async {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return null;
    ZugDialogs.currentContexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Align(
              alignment: alignment,
              child: WidgetSelectDialog(prompt,widgetList, axisCount, showTime: showTime, seconds: seconds, sizeFactor: sizeFactor, color: color, backgroundColor: backgroundColor));
        }).then((widget) {
      return widget;
    });
  }

  static Future<void> showAnimationDialog (AnimationDialog dial, {Alignment alignment = Alignment.center}) {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return Future(() => null);
    ZugDialogs.currentContexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return Align(alignment: alignment, child: dial);
        }).then((ok)  {
      return Future(() => null);
    });
  }

  static Future<void> showClickableDialog(Widget widget) {
    BuildContext? ctx = _navigatorKey?.currentContext;
    if (ctx == null) return Future(() => null);
    ZugDialogs.currentContexts.add(ctx);
    return showDialog(
        context: ctx,
        builder: (BuildContext context) {
          return ClickableDialog(widget);
        }).then((ok)  {
      return Future(() => null);
    });
  }

}

class ClickableDialog extends StatelessWidget {
  final Widget widget;

  const ClickableDialog(this.widget, {super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
        alignment: Alignment.center,
        elevation: 10,
        child: GestureDetector(
          onTap: () { Navigator.pop(context); },
          child: widget,
        )
    );
  }
}

class ValueDialog extends StatelessWidget {
  final String prompt;
  final dynamic defVal;
  final Color bkgColor;
  final Color color;
  final Widget options;

  const ValueDialog(this.options, {
    this.prompt = "",this.defVal = "",
    this.bkgColor = Colors.black, this.color = Colors.white, super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      backgroundColor: bkgColor,
      elevation: 10,
      child: prompt.isEmpty ? options : Column(
        children: [
          Text(prompt, style: TextStyle(color: color)),
          options
        ],
      ),
    );
  }
}

class TextDialog extends StatelessWidget {
  final TextEditingController titleControl = TextEditingController();
  final String prompt;
  TextDialog(this.prompt,String defTxt, {super.key}) {
    titleControl.text = defTxt;
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      backgroundColor: Colors.green,
      elevation: 10,
      title: Text(prompt),
      children: [
        TextField(
          controller: titleControl,
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context, titleControl.text);
          },
          child: const Text('Enter'),
        ),
      ],
    );
  }
}

class CancellableDialog extends StatelessWidget {
  final ValueNotifier<bool?> canceller;
  final Widget dialog;
  const CancellableDialog(this.dialog, this.canceller, {super.key});

  @override
  Widget build(BuildContext context) {
    return DialogListener<bool?>(
        listenable: canceller,
        listener: (before,after) {
          if (before == null && after != null) ZugDialogs.popDialog(context);
        },
        builder: (context) => dialog
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String txt;
  final String imageFilename;
  const ConfirmDialog(this.txt, {this.imageFilename = "", super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
        imageFilename.isEmpty
            ? const SizedBox.shrink()
            : Image.asset("assets/images/$imageFilename"),
        Center(child: Text(txt)),
        SimpleDialogOption(
            onPressed: () {
              ZugDialogs.popDialog(context, true);
            },
            child: const Text('OK')),
        SimpleDialogOption(
            onPressed: () {
              ZugDialogs.popDialog(context, false);
            },
            child: const Text('Cancel')),
      ],
    );
  }
}

class NotificationDialog extends StatelessWidget {
  final String txt;
  final String imageFilename;
  const NotificationDialog(this.txt, {this.imageFilename = "", super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
        InkWell(
            onTap: () {
              Navigator.pop(context, true);
            },
            child: Column(
              children: [
                Text(txt),
                imageFilename.isEmpty
                    ? const SizedBox()
                    : Image.asset("assets/images/$imageFilename"),
              ],
            )),
      ],
    );
  }
}

class IconSelectDialog extends StatelessWidget {
  final String prompt;
  final List<Icon> iconList;
  const IconSelectDialog(this.prompt,this.iconList, {super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(prompt),
            ]
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(iconList.length, (index) =>
              IconButton(
                  onPressed: () {
                    Navigator.pop(context, index);
                  },
                  icon: iconList.elementAt(index))
          ),
        )
      ],
    );
  }
}

class ItemSelectDialog extends StatelessWidget {
  final String actionString;
  final List<dynamic> itemList;
  final List<String> fieldList;
  final double sizeFactor;
  const ItemSelectDialog(this.itemList, this.fieldList, this.actionString, {this.sizeFactor = 1, super.key});

  @override
  Widget build(BuildContext context) {
    final double widgetWidth = MediaQuery.of(context).size.width;
    final double widgetHeight = MediaQuery.of(context).size.height;

    return SimpleDialog(
      children: [
        IconButton(onPressed: () {Navigator.pop(context,-1);}, icon: const Icon(Icons.cancel)),
        Container(
          color : Colors.black,
          width : widgetWidth,
          height: widgetHeight,
          child: ListView(
            scrollDirection: Axis.vertical,
            children:
            List.generate(itemList.length, (index) =>
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    itemRow(itemList[index],fieldList),
                    ElevatedButton(
                      onPressed: () { Navigator.pop(context,itemList[index]); },
                      child: Text(actionString),
                    ),
                  ],
                )
            ),
          ),
        )
      ],
    );
  }

  Widget itemRow(data, List<String> fieldList) {
    return Row(
        children:
        List.generate(fieldList.length, (index) => Text(
            "${fieldList.elementAt(index)}: data[fieldList.elementAt(index)")
        )
    );
  }

}

abstract class TimedDialog extends StatefulWidget {
  final bool showTime;
  final int milliseconds;
  final int framerate;
  bool timeOut = false;
  Future<dynamic>? countThread;
  TimedDialog(this.milliseconds,this.showTime, {this.framerate = 1000, super.key});

  void cancel() {
    timeOut = true;
    countThread?.timeout(const Duration(milliseconds: 50));
  }
}

abstract class TimedDialogState extends State<TimedDialog> {
  int timeRemaining = 0;
  bool countingDown = false;

  @override
  void initState() { //print("Millis: ${widget.milliseconds}");
    super.initState();
    countingDown = widget.milliseconds > 0;
    timeRemaining = widget.milliseconds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (countingDown) countdown();
    });
  }

  Future<void> countdown() async { //print("Counting down");
    while (timeRemaining > 0) {
      widget.countThread = Future.delayed(Duration(milliseconds: widget.framerate)).then((value) {
        if (countingDown) {
          setState(() { timeRemaining -= widget.framerate; });
        }
      });
      await widget.countThread;
    } //countingDown = false;
  }

  @override
  void dispose() {
    countingDown = false;
    super.dispose();
  }

  bool checkTime() {
    if (widget.timeOut || (countingDown && timeRemaining <= 0)) {
      Navigator.pop(context,null);
      return true;
    }
    return false;
  }

  int secondsRemaining() {
    return (timeRemaining/1000).round();
  }
}

class WidgetSelectDialog extends TimedDialog {
  final Color color;
  final Color backgroundColor;
  final int axisCount;
  final double buffer;
  final String prompt;
  final Offset sizeFactor;
  final List<Widget> widgets;
  WidgetSelectDialog(this.prompt, this.widgets, this.axisCount,
      {seconds = 0, showTime = false, this.buffer = 8, this.sizeFactor = const Offset(1, 1), this.color = Colors.white, this.backgroundColor = Colors.black, super.key}) : super(seconds * 1000, showTime);

  @override
  State<StatefulWidget> createState() => _WidgetSelectState();

}

class _WidgetSelectState extends TimedDialogState {

  @override
  Widget build(BuildContext context) {
    var w = widget;
    if (w is WidgetSelectDialog) {
      if (checkTime() || w.widgets.isEmpty) {
        return const SizedBox.shrink();
      }
      else {
        final double dialogWidth = MediaQuery.of(context).size.width * w.sizeFactor.dx;
        final double dialogHeight = MediaQuery.of(context).size.height * w.sizeFactor.dy;
        bool portrait = dialogWidth <= dialogHeight;
        TextStyle textStyle = TextStyle(
            backgroundColor: w.backgroundColor.withOpacity(1),
            color: w.color,
            decoration: TextDecoration.none
        );
        return Container(
            width: dialogWidth,
            height: dialogHeight,
            color: w.backgroundColor,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(w.prompt, style: textStyle),
                    widget.showTime ? Text(secondsRemaining().toString(),style: textStyle) : const Text("")
                  ],
                ),
                Expanded(child: GridView.count(
                    padding: EdgeInsets.all(w.buffer),
                    crossAxisSpacing: w.buffer,
                    mainAxisSpacing: w.buffer,
                    scrollDirection: portrait ? Axis.horizontal : Axis.vertical,
                    crossAxisCount: w.axisCount,
                    children: List.generate(
                        w.widgets.length,
                            (index) => GestureDetector(
                          onTap: () => Navigator.pop(
                              context, w.widgets.elementAt(index)),
                          child: w.widgets.elementAt(index),
                        )
                    )
                )),
              ],
            )
        );
      }
    }
    else {
      return const Text("Error");
    }
  }
}

class WidgetDim {
  double width, height;
  WidgetDim(this.width,this.height);
}

abstract class AnimationDialog extends TimedDialog {
  final double sizeFactor;
  AnimationDialog(milliseconds, {this.sizeFactor = 1, framerate = 0, showTime = false, super.key}) : super(milliseconds, showTime, framerate : framerate > 0 ? framerate : milliseconds);
}

abstract class AnimationDialogState extends TimedDialogState {
  int frame = 0;

  @override
  Future<void> countdown() async {
    setState(() {}); //initial state
    super.countdown();
  }

  @override
  Widget build(BuildContext context) {
    frame++;
    return nextFrame(context);
  }

  Widget nextFrame(BuildContext context);

}