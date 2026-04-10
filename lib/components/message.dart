part of "components.dart";

void hideAllMessages() {
  _OverlayWidgetState.removeAll();
}

void showToast({required String message, Widget? icon, Widget? trailing}) {
  var newEntry = OverlayEntry(
      builder: (context) => _ToastOverlay(
            message: message,
            icon: icon,
            trailing: trailing,
          ));

  _OverlayWidgetState.addOverlay(newEntry);

  Timer(const Duration(seconds: 2), () => _OverlayWidgetState.remove(newEntry));
}

class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({required this.message, this.icon, this.trailing});

  final String message;

  final Widget? icon;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) icon!.paddingRight(8),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                  maxLines: 3,
                ),
                if (trailing != null) trailing!.paddingLeft(8)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget(this.child, {super.key});

  final Widget child;

  static void addOverlay(OverlayEntry entry) =>
      _OverlayWidgetState.addOverlay(entry);

  static void removeAll() => _OverlayWidgetState.removeAll();

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  static var overlayKey = GlobalKey<OverlayState>();

  static var entries = <OverlayEntry>[];

  static void addOverlay(OverlayEntry entry) {
    if (overlayKey.currentState != null) {
      overlayKey.currentState!.insert(entry);
      entries.add(entry);
    }
  }

  static void remove(OverlayEntry entry) {
    if (entries.remove(entry)) {
      entry.remove();
    }
  }

  static void removeAll() {
    for (var entry in entries) {
      entry.remove();
    }
    entries.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      key: overlayKey,
      initialEntries: [OverlayEntry(builder: (context) => widget.child)],
    );
  }
}

void showDialogMessage(BuildContext context, String title, String message) {
  if (App.isFluent) {
    fluent.showDialog(
      context: context,
      builder: (context) => fluent.ContentDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          fluent.Button(
              onPressed: () => App.back(context), child: Text("了解".tl))
        ],
      ),
    );
    return;
  }
  showDialog(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => App.back(context), child: Text("了解".tl))
            ],
          ));
}

Future<void> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required void Function() onConfirm,
  String confirmText = "确认",
  Color? btnColor,
}) {
  return showDialog(
    context: context,
    builder: (context) => ContentDialog(
      title: title,
      content: Text(content).paddingHorizontal(16).paddingVertical(8),
      actions: [
        FilledButton(
          onPressed: () {
            context.pop();
            onConfirm();
          },
          style: FilledButton.styleFrom(
            backgroundColor: btnColor,
          ),
          child: Text(confirmText.tl),
        ),
      ],
    ),
  );
}

Future<void> showInputDialog({
  required BuildContext context,
  required String title,
  String? hintText,
  required FutureOr<Object?> Function(String) onConfirm,
  String? initialValue,
  String confirmText = "确认",
  String cancelText = "取消",
  RegExp? inputValidator,
  String? image,
  Uint8List? imageData,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  String? labelText,
  Widget? prefix,
  String? suffixText,
}) {
  var controller = TextEditingController(text: initialValue);
  bool isLoading = false;
  String? error;

  return showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return ContentDialog(
            title: title,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (image != null)
                  SizedBox(
                    height: 108,
                    child: Image.network(image, fit: BoxFit.none),
                  ).paddingBottom(8),
                if (image == null && imageData != null)
                  SizedBox(
                    height: 108,
                    child: Image.memory(imageData, fit: BoxFit.none),
                  ).paddingBottom(8),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  decoration: InputDecoration(
                    hintText: hintText,
                    labelText: labelText,
                    prefix: prefix,
                    suffixText: suffixText,
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ).paddingHorizontal(12),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  context.pop();
                },
                child: Text(cancelText.tl),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (inputValidator != null &&
                            !inputValidator.hasMatch(controller.text)) {
                          setState(() => error = "Invalid input");
                          return;
                        }
                        var futureOr = onConfirm(controller.text);
                        Object? result;
                        if (futureOr is Future) {
                          setState(() => isLoading = true);
                          result = await futureOr;
                          setState(() => isLoading = false);
                        } else {
                          result = futureOr;
                        }
                        if (result == null) {
                          // 延迟关闭对话框，确保 onConfirm 中的导航操作先执行
                          // 避免同时关闭对话框和导航导致的 StateController 问题
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (context.mounted) {
                              context.pop();
                            }
                          });
                        } else {
                          setState(() => error = result.toString());
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(confirmText.tl),
              ),
            ],
          );
        },
      );
    },
  );
}

class LoadingDialogController {
  double? _progress;

  String? _message;

  void Function()? closeDialog;

  void Function(double? value)? _setProgress;

  void Function(String message)? _setMessage;

  bool closed = false;

  void close() {
    if (closed) {
      return;
    }
    closed = true;
    if (closeDialog == null) {
      Future.microtask(closeDialog!);
    } else {
      closeDialog!();
    }
  }

  void setProgress(double? value) {
    if (closed) {
      return;
    }
    _setProgress?.call(value);
  }

  void setMessage(String message) {
    if (closed) {
      return;
    }
    _setMessage?.call(message);
  }
}

LoadingDialogController showLoadingDialog(
  BuildContext context, {
  void Function()? onCancel,
  bool barrierDismissible = true,
  bool allowCancel = true,
  String? message,
  String cancelButtonText = "Cancel",
  bool withProgress = false,
}) {
  var controller = LoadingDialogController();
  controller._message = message;

  if (withProgress) {
    controller._progress = 0;
  }

  var loadingDialogRoute = DialogRoute(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return StatefulBuilder(builder: (context, setState) {
        controller._setProgress = (value) {
          setState(() {
            controller._progress = value;
          });
        };
        controller._setMessage = (msg) {
          setState(() {
            controller._message = msg;
          });
        };
        return ContentDialog(
          title: controller._message ?? 'Loading',
          content: withProgress
              ? LinearProgressIndicator(
                  value: controller._progress,
                  backgroundColor: context.colorScheme.surfaceContainer,
                ).paddingHorizontal(16).paddingVertical(16)
              : const Center(
                  child: CircularProgressIndicator(),
                ).paddingVertical(32),
          actions: [
            FilledButton(
              onPressed: allowCancel
                  ? () {
                      controller.close();
                      onCancel?.call();
                    }
                  : null,
              child: Text(cancelButtonText.tl),
            )
          ],
        );
      });
    },
  );

  var navigator = Navigator.of(context, rootNavigator: true);

  navigator.push(loadingDialogRoute).then((value) => controller.closed = true);

  controller.closeDialog = () {
    navigator.removeRoute(loadingDialogRoute);
  };

  return controller;
}

class ContentDialog extends StatelessWidget {
  const ContentDialog({
    super.key,
    this.title,
    required this.content,
    this.dismissible = true,
    this.actions = const [],
  });

  final String? title;

  final Widget content;

  final List<Widget> actions;

  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    var dialogContent = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title != null
              ? Appbar(
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: dismissible ? context.pop : null,
                  ),
                  title: Text(title!),
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox.shrink(),
          this.content,
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions,
          ).paddingRight(12),
          const SizedBox(height: 16),
        ],
      ),
    );
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: context.brightness == Brightness.dark
            ? BorderSide(color: context.colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      insetPadding: context.width < 400
          ? const EdgeInsets.symmetric(horizontal: 4)
          : const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      shadowColor: context.colorScheme.shadow,
      backgroundColor: context.colorScheme.surface,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              minWidth: math.min(400, context.width - 16),
            ),
            child: MediaQuery.removePadding(
              removeTop: true,
              removeBottom: true,
              context: context,
              child: dialogContent,
            ),
          ),
        ),
      ),
    );
  }
}
