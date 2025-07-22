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

export class LiveViewStyleInformation extends DefaultStyleInformation {
  title: string;
  text: string;
  typeCode: number;
  initialTime: number = 3000;
  isCountDown: boolean = false;
  isPaused: boolean = false;
  isInTitle: boolean = false;

  constructor(htmlFormatTitle: boolean, htmlFormatBody: boolean, title: string, text: string, typeCode: number,
    initialTime: number, isCountDown: boolean,
    isPaused: boolean, isInTitle: boolean) {
    super(htmlFormatTitle, htmlFormatBody);
    this.title = title;
    this.text = text;
    this.typeCode = typeCode;

    this.initialTime = initialTime;
    this.isCountDown = isCountDown;
    this.isPaused = isPaused;
    this.isInTitle = isInTitle;
  }
}