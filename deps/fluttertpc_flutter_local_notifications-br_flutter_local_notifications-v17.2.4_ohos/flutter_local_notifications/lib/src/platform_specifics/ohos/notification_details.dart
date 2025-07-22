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

import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui';

import '../../../flutter_local_notifications.dart';

class OhosNotificationActionInput {
  const OhosNotificationActionInput();
}

class OhosNotificationAction {
  const OhosNotificationAction(this.id, this.title,
      {this.inputs = const <OhosNotificationActionInput>[]});

  final String id;

  final String title;

  final List<OhosNotificationActionInput> inputs;
}

class OhosNotificationDetails {
  const OhosNotificationDetails(this.slotType,
      {this.slotDesc,
      this.icon,
      this.importance = OhosImportance.defaultImportance,
      this.styleInformation,
      this.playSound = true,
      this.sound,
      this.enableVibration = true,
      this.vibrationPattern,
      this.groupKey,
      this.autoCancel = true,
      this.ongoing = false,
      this.silent = false,
      this.color,
      this.largeIcon,
      this.onlyAlertOnce = false,
      this.showWhen = true,
      this.when,
      this.usesChronometer = false,
      this.chronometerCountDown = false,
      this.slotShowBadge = true,
      this.showProgress = false,
      this.maxProgress = 0,
      this.progress = 0,
      this.indeterminate = false,
      this.slotAction = OhosNotificationSlotAction.createIfNotExists,
      this.enableLights = false,
      this.ledColor,
      this.timeoutAfter,
      this.fullScreenIntent = false,
      this.subText,
      this.tag,
      this.actions,
      this.colorized = false,
      this.badgeNumber,
      this.lockscreenVisibility,
      this.bypassDnd,
        this.isFloatingIcon,
      });

  final String? icon;

  final OhosNotificationSlotType slotType;

  final String? slotDesc;

  final bool slotShowBadge;

  final OhosImportance importance;

  final bool playSound;

  final OhosNotificationSound? sound;

  final bool enableVibration;

  final bool enableLights;

  // final Int64List? vibrationPattern;

  final List<int>? vibrationPattern;

  final OhosStyleInformation? styleInformation;

  final String? groupKey;

  final bool autoCancel;

  final bool ongoing;

  final bool silent;

  final Color? color;

  final OhosPixelMap<Object>? largeIcon;

  final bool onlyAlertOnce;

  final bool showWhen;

  final int? when;

  final bool usesChronometer;

  final bool chronometerCountDown;

  final bool showProgress;

  final int maxProgress;

  final int progress;

  final bool indeterminate;

  final Color? ledColor;

  final OhosNotificationSlotAction slotAction;

  final int? timeoutAfter;

  final bool fullScreenIntent;

  final List<OhosNotificationAction>? actions;

  final String? subText;

  final String? tag;

  final bool colorized;

  final int? badgeNumber;

  final bool? lockscreenVisibility;

  final bool? bypassDnd;

  final bool? isFloatingIcon;
}
