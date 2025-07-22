/*
 * Copyright (c) 2024 Shenzhen Kaihong Digital Industry Development Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'default_style_information.dart';

class OhosInboxStyleInformation extends OhosDefaultStyleInformation {
  const OhosInboxStyleInformation(
    this.lines, {
    this.htmlFormatLines = false,
    this.contentTitle,
    this.htmlFormatContentTitle = false,
    this.summaryText,
    this.htmlFormatSummaryText = false,
    bool htmlFormatContent = false,
    bool htmlFormatTitle = false,
  }) : super(htmlFormatContent, htmlFormatTitle);

  final String? contentTitle;

  final String? summaryText;

  final List<String> lines;

  final bool htmlFormatLines;

  final bool htmlFormatContentTitle;

  final bool htmlFormatSummaryText;
}
