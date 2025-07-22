import 'dart:math';

extension GenerateFilename on Random {
  String randomFileName({required String prefix, int length = 16}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ012346789';

    final buffer = StringBuffer(prefix);
    for (var i = 0; i < length; i++) {
      buffer.writeCharCode(chars.codeUnitAt(nextInt(chars.length)));
    }

    return buffer.toString();
  }
}
