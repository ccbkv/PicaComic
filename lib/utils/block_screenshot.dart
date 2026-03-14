import 'package:flutter/services.dart';

void blockScreenshot(){
  const MethodChannel("com.github.pacalini.pica_comic/screenshot").invokeMethod("blockScreenshot");
}