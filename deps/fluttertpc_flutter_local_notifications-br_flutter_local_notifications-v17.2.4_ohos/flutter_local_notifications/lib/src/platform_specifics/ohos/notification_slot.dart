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

import 'dart:typed_data';
import 'dart:ui';

import 'enums.dart';
import 'notification_sound.dart';

class OhosNotificationSlot {
  const OhosNotificationSlot(this.slotType,
      {this.description,
      this.importance = OhosImportance.defaultImportance,
      this.playSound = true,
      this.sound,
      this.enableVibration = true,
      this.vibrationPattern,
      this.showBadge = true,
      this.enableLights = false,
      this.ledColor,
      this.lockscreenVisibility,
      this.bypassDnd,
      this.slotAction = OhosNotificationSlotAction.createIfNotExists});

  final OhosNotificationSlotType slotType;

  final String? description;

  final OhosImportance importance;

  final bool playSound;

  final OhosNotificationSound? sound;

  final bool enableVibration;

  final bool enableLights;

  final Int64List? vibrationPattern;

  final Color? ledColor;

  final bool showBadge;

  final OhosNotificationSlotAction slotAction;

  final bool? lockscreenVisibility;

  final bool? bypassDnd;
}
