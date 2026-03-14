import 'package:flutter/material.dart';
import 'package:pica_comic/components/delayed_modal_barrier.dart';

Future<T?> showDelayedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor = Colors.black54,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  return showGeneralDialog(
    context: context,
    pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
      final Widget pageChild = Builder(builder: builder);
      Widget dialog = pageChild;
      if(useSafeArea){
        dialog = SafeArea(child: dialog);
      }
      return DelayedModalBarrier(
        color: barrierDismissible ? barrierColor : Colors.transparent,
        barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
        child: Center(child: dialog),
      );
    },
    barrierDismissible: false,
    barrierLabel: null,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    transitionBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ),
      child: child,
    ),
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
}