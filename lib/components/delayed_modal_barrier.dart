import 'package:flutter/material.dart';

class DelayedModalBarrier extends StatefulWidget {
  const DelayedModalBarrier({
    super.key,
    this.color,
    this.duration = const Duration(milliseconds: 500),
    this.barrierLabel,
    this.child,
  });

  final Color? color;
  final Duration duration;
  final String? barrierLabel;
  final Widget? child;

  @override
  State<DelayedModalBarrier> createState() => _DelayedModalBarrierState();
}

class _DelayedModalBarrierState extends State<DelayedModalBarrier> {
  bool _dismissible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) {
        setState(() {
          _dismissible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalBarrier(
          color: widget.color,
          dismissible: _dismissible,
          semanticsLabel: _dismissible ? widget.barrierLabel : null,
        ),
        if (widget.child != null)
          Center(
            child: widget.child,
          ),
      ],
    );
  }
}