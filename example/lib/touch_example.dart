import 'dart:math';

import 'package:flutter/material.dart';
import 'package:keyboard_avoider/bottom_area_avoider.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';

void main() => runApp(TouchAvoiderExampleApp());

class TouchAvoiderExampleApp extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Row(
        children: <Widget>[
          Flexible(
            flex: 1,
            child: Column(
              children: <Widget>[
                Flexible(flex: 2, child: _buildPlaceholder(Colors.red)),
                Flexible(flex: 1, child: _buildPlaceholder(Colors.pink)),
              ],
            ),
          ),
          Flexible(
            flex: 2,
            child: Column(
              children: <Widget>[
                Flexible(flex: 2, child: _buildForm(40, Colors.green)),
                Flexible(flex: 1, child: _buildPlaceholder(Colors.lightGreen),
                ),
              ],
            ),
          ),
          Flexible(
            flex: 1,
            child: Column(
              children: <Widget>[
                Flexible(flex: 1, child: _buildPlaceholder(Colors.blue)),
                Flexible(flex: 2, child: _buildPlaceholder(Colors.lightBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(int rows, Color color) {
    return Container(
      color: color,
      child: KeyboardAvoider(
        autoScroll: true,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          controller: _scrollController,
          itemCount: rows,
          itemBuilder: (context, index) {
            return Material(
              child: TextFormField(
                initialValue: 'TextFormField ${index + 1}',
                decoration: InputDecoration(fillColor: color, filled: true),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color color) {
    return TouchAvoider(
      child: Container(
        color: color,
        child: Placeholder(),
      ),
    );
  }
}

/// Fun example avoider that re-sizes to wherever the user most recently dragged.
class TouchAvoider extends StatefulWidget {
  final Widget child;
  const TouchAvoider({Key key, this.child}) : super(key: key);

  @override
  _TouchAvoiderState createState() => _TouchAvoiderState();
}

class _TouchAvoiderState extends State<TouchAvoider> {
  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => debugPrint('tappt'),
      onPanUpdate: (du) => _userTouched(du.globalPosition),
      child: BottomAreaAvoider(
        areaToAvoid: max(_offset, 0.0),
        child: widget.child,
        duration: Duration(milliseconds: 50),
      ),
    );
  }

  _userTouched(Offset globalTouchPosition) {
    debugPrint('touched $globalTouchPosition');

    // Calculate distance from the bottom of child to the touched area
    double offset = globalTouchPosition.dy;

    // Calculate Rect of widget on screen
    final object = context.findRenderObject();
    final box = object as RenderBox;
    final globalOffset = box.localToGlobal(Offset.zero);
    final widgetRect = Rect.fromLTWH(
      globalOffset.dx,
      globalOffset.dy,
      box.size.width,
      box.size.height,
    );

    // Update the offset to that;
    setState(() {
      _offset = widgetRect.bottom - globalTouchPosition.dy;
    });
  }
}