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

import { DefaultStyleInformation } from './DefaultStyleInfomation';

export class InBoxStyleInformation extends DefaultStyleInformation {
  lines: Array<string>;
  contentTitle: string;
  summaryText: string;

  htmlFormatContentTitle: boolean;
  htmlFormatLines: boolean;
  htmlFormatSummaryText: boolean;

  constructor(htmlFormatTitle: boolean, htmlFormatBody: boolean, contentTitle: string, lines: Array<string>, summaryText: string, htmlFormatContentTitle: boolean, htmlFormatLines: boolean, htmlFormatSummaryText: boolean) {
    super(htmlFormatTitle, htmlFormatBody);
    this.lines = lines;
    this.contentTitle = contentTitle;
    this.summaryText = summaryText;
    this.htmlFormatContentTitle = htmlFormatContentTitle;
    this.htmlFormatLines = htmlFormatLines;
    this.htmlFormatSummaryText = htmlFormatSummaryText;
  }
}