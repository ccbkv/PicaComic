import 'default_style_information.dart';

class OhosLiveViewStyleInformation extends OhosDefaultStyleInformation {
  const OhosLiveViewStyleInformation(
      this.title, this.text, this.typeCode, {
        this.initialTime,
        this.isCountDown,
        this.isPaused = false,
        this.isInTitle = false,
        bool htmlFormatContent = false,
        bool htmlFormatTitle = false,
      }) : super(htmlFormatContent, htmlFormatTitle);

  final String title;
  final String text;
  final int typeCode;
  final double? initialTime;
  final bool? isCountDown;
  final bool? isPaused;
  final bool? isInTitle;
}