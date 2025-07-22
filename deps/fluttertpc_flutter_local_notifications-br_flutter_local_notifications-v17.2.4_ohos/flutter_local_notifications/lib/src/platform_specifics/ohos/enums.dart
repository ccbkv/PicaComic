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
enum OhosNotificationSoundSource {
  rawResource,

  uri,
}

enum OhosNotificationSlotAction {
  createIfNotExists,

  update
}

enum OhosBitmapSource {
  drawable,

  filePath,

  byteArray,
}

enum OhosImportance {
  none(0),

  min(1),

  low(2),

  defaultImportance(3),

  high(4);

  const OhosImportance(this.value);

  final int value;
}

enum OhosNotificationStyle {
  defaultStyle,

  bigPicture,

  bigText,

  inbox,

  messaging,

  liveView
}

enum OhosNotificationSlotType {
  UNKNOWN_TYPE(0),
  SOCIAL_COMMUNICATION(1),
  SERVICE_INFORMATION(2),
  CONTENT_INFORMATION(3),
  LIVE_VIEW(4),
  CUSTOMER_SERVICE(5),
  OTHER_TYPES(0xFFFF);
  const OhosNotificationSlotType(this.value);

  final int value;
}