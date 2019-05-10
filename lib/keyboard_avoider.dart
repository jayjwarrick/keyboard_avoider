import 'dart:math';
import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

const double _focusPaddingDefault = 12.0;

/// Wraps the [child] in a [AnimatedContainer] that adjusts its bottom [padding] to accommodate the on-screen keyboard.
/// Unlike a [Scaffold], it only insets by the actual amount obscured by the keyboard.
/// If [autoScroll] is true and the [child] contains a focused widget such as a [TextField],
/// automatically scrolls so that it is just visible above the keyboard, plus any additional [focusPadding].
class KeyboardAvoider extends StatefulWidget {
  /// The child to embed. If the [child] is not a [ScrollView], it is automatically embedded in a [SingleChildScrollView].
  /// If the [child] is a [ScrollView], it must have a [ScrollController].
  final Widget child;

  /// Duration of the resize animation. Defaults to 100ms. To disable, set to [Duration.zero].
  final Duration duration;

  /// Animation curve. Defaults to [easeOut]
  final Curve curve;

  /// Whether to auto-scroll to the focused widget after the keyboard appears. Defaults to false.
  /// Could be expensive because it searches all the child objects in this widget's render tree.
  final bool autoScroll;

  /// Space to put between the focused widget and the top of the keyboard. Defaults to [_focusPaddingDefault].
  /// Useful in case the focused widget is inside a parent widget that you also want to be visible, or
  /// there is additional overlay besides they keyboard you need to account for.
  final double focusPadding;

  KeyboardAvoider({
    Key key,
    @required this.child,
    this.duration = const Duration(milliseconds: 100),
    this.curve = Curves.easeOut,
    this.autoScroll = false,
    this.focusPadding = _focusPaddingDefault,
  })  : assert(child is ScrollView ? child.controller != null : true),
        super(key: key);

  _KeyboardAvoiderState createState() => _KeyboardAvoiderState();
}

class _KeyboardAvoiderState extends State<KeyboardAvoider> with WidgetsBindingObserver {
  final _animationKey = new GlobalKey<ImplicitlyAnimatedWidgetState>();
  Function(AnimationStatus) _animationListener;
  ScrollController _scrollController;
  double _overlap = 0.0;
  double _previousOverlap = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationKey.currentState?.animation?.removeStatusListener(_animationListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if resize is needed after each build, as the widget's [focusPadding] may have changed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resize();
    });

    // Add a status listener to the animation after the initial build.
    // Wait a frame so that _animationKey.currentState is not null.
    if (_animationListener == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animationListener = _animationStatusChanged;
        _animationKey.currentState.animation.addStatusListener(_animationListener);
      });
    }

    // If [child] is a [ScrollView], get its [ScrollController]
    // and embed the [child] directly in an [AnimatedContainer].
    if (widget.child is ScrollView) {
      var scrollView = widget.child as ScrollView;
      _scrollController = scrollView.controller;
      return _buildAnimatedContainer(widget.child);
    }

    // If [child] is not a [ScrollView], and [autoScroll] is true,
    // embed the [child] in a [SingleChildScrollView] to make
    // it possible to scroll to the focused widget.
    if (widget.autoScroll) {
      _scrollController = new ScrollController();
      return _buildAnimatedContainer(LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: widget.child,
            ),
          );
        },
      ));
    }

    // Just embed the [child] directly in an [AnimatedContainer].
    return _buildAnimatedContainer(widget.child);
  }

  /// WidgetsBindingObserver

  /// TODO can we remove this, and rely on resize being called from build()?
  @override
  void didChangeMetrics() {
    //Need to wait a frame to get the new size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resize();
    });
  }

  /// AnimationStatus

  void _animationStatusChanged(AnimationStatus status) {
    debugPrint('_animationStatusChanged $status');
    if (status == AnimationStatus.completed) {
//      final keyboardVisible = MediaQuery.of(context).viewInsets.bottom + widget.focusPadding !=
//          _focusPaddingDefault;
//      if (keyboardVisible) {
      if (_previousOverlap < _overlap) {
        // Keyboard is showing.
        _keyboardShown();
      }
    }
  }

  /// Private

  Widget _buildAnimatedContainer(Widget child) {
    debugPrint('buildAnimatedContainer w $_overlap');
    return AnimatedContainer(
      key: _animationKey,
      padding: EdgeInsets.only(bottom: _overlap),
      duration: widget.duration,
      curve: widget.curve,
      child: child,
    );
  }

  void _resize() {
    if (context == null) {
      return;
    }

    // Calculate Rect of widget on screen
    final object = context.findRenderObject();
    final box = object as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final widgetRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      box.size.width,
      box.size.height,
    );

    // Calculate top of keyboard
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final screenInsets = mediaQuery.viewInsets;
    final keyboardTop = screenSize.height - (screenInsets.bottom + widget.focusPadding);

    // If widget is entirely covered by keyboard, do nothing
//    if (widgetRect.top > keyboardTop) {
//      return;
//    }

    // If widget is partially obscured by the keyboard, adjust bottom padding to fully expose it
    final overlap = max(0.0, widgetRect.bottom - keyboardTop);
    if (overlap != _overlap) {
      setState(() {
        debugPrint('KeyboardAvoider UPDATE overlap $_overlap --> $overlap}');
        _previousOverlap = _overlap;
        _overlap = overlap;
      });
    }
  }

  void _keyboardShown() {
    // If auto scroll is not enabled, do nothing
    if (!widget.autoScroll) {
      return;
    }
    // Need to wait a frame to get the new size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFocusedObject(context);
    });
  }

  void _scrollToFocusedObject(BuildContext context) {
    if (context == null) {
      return;
    }

    final focused = _findFocusedObject(context.findRenderObject());
    if (focused != null) {
      _scrollToObject(focused);
    }
  }

  /// Finds the first focused focused child of [root] using a breadth-first search.
  RenderObject _findFocusedObject(RenderObject root) {
    final q = Queue<RenderObject>();
    q.add(root);
    while (q.isNotEmpty) {
      final node = q.removeFirst();
      final config = SemanticsConfiguration();
      node.describeSemanticsConfiguration(config);
      if (config.isFocused) {
        return node;
      }
      node.visitChildrenForSemantics((child) {
        q.add(child);
      });
    }
    return null;
  }

  /// If the focused object is covered by the keyboard, scroll to it.
  ///
  /// Otherwise do nothing.
  _scrollToObject(RenderObject object) {
    // Calculate the offset needed to show the object in the [ScrollView]
    // so that its bottom touches the top of the keyboard.
    final viewport = RenderAbstractViewport.of(object);
    final offset = viewport.getOffsetToReveal(object, 1.0).offset + widget.focusPadding;

    // If the object is covered by the keyboard, scroll to reveal it,
    // and add [focusPadding] between it and top of the keyboard.
    if (offset > _scrollController.position.pixels) {
      _scrollController.position.moveTo(
        offset,
        duration: widget.duration,
        curve: widget.curve,
      );
    }
  }
}
