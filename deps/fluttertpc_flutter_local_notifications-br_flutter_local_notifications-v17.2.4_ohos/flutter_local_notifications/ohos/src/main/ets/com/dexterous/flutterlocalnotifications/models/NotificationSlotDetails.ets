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

import { MethodCall } from '@ohos/flutter_ohos';
import { LocalNotificationsConstants } from '../LocalNotificationsConstants';
import NotificationDetails from './NotificationDetails';
import { NotificationSlotAction } from './NotificationSlotAction';
import { SoundSource } from './SoundSource';
import { notificationManager } from '@kit.NotificationKit';

export default class NotificationSlotDetails {
  slotType: number = 0;
  description?: string;
  showBadge?: boolean;
  importance?: number;
  playSound?: boolean;
  sound?: string;
  soundSource?: SoundSource;
  enableVibration?: boolean;
  vibrationPattern?: Array<number>;
  slotAction?: NotificationSlotAction;
  enableLights?: boolean;
  ledColor?: number;
  lockscreenVisibility?: boolean;
  bypassDnd?: boolean;

  public static from(call: MethodCall): NotificationSlotDetails {
    let notificationSlotDetails = new NotificationSlotDetails();
    notificationSlotDetails.slotType = call.argument(LocalNotificationsConstants.SLOT_TYPE);
    notificationSlotDetails.description = call.argument(LocalNotificationsConstants.DESCRIPTION);
    notificationSlotDetails.showBadge = call.argument(LocalNotificationsConstants.SHOW_BADGE);
    notificationSlotDetails.importance = call.argument(LocalNotificationsConstants.IMPORTANCE);
    notificationSlotDetails.playSound = call.argument(LocalNotificationsConstants.PLAY_SOUND);
    notificationSlotDetails.sound = call.argument(LocalNotificationsConstants.SOUND);
    notificationSlotDetails.soundSource = call.argument(LocalNotificationsConstants.SOUND_SOURCE);
    notificationSlotDetails.enableVibration = call.argument(LocalNotificationsConstants.ENABLE_VIBRATION);
    notificationSlotDetails.vibrationPattern = call.argument(LocalNotificationsConstants.VIBRATION_PATTERN);
    notificationSlotDetails.slotAction = call.argument(LocalNotificationsConstants.SLOT_ACTION);
    notificationSlotDetails.enableLights = call.argument(LocalNotificationsConstants.ENABLE_LIGHTS);
    let alpha: number | undefined = call.argument(LocalNotificationsConstants.LED_COLOR_ALPHA);
    let red: number | undefined = call.argument(LocalNotificationsConstants.LED_COLOR_RED);
    let green: number | undefined = call.argument(LocalNotificationsConstants.LED_COLOR_GREEN);
    let blue: number | undefined = call.argument(LocalNotificationsConstants.LED_COLOR_BLUE);
    if (alpha && red && green && blue) {
      notificationSlotDetails.ledColor = (alpha << 24) | (red << 16) | (green << 8) | blue;
    }
    notificationSlotDetails.lockscreenVisibility = call.argument(LocalNotificationsConstants.LOCKSCREEN_VISIBILITY);
    notificationSlotDetails.bypassDnd = call.argument(LocalNotificationsConstants.BYPASSDND);
    return notificationSlotDetails;
  }

  public static fromNotificationDetails(notificationDetails: NotificationDetails): NotificationSlotDetails {
    let notificationSlotDetails: NotificationSlotDetails = new NotificationSlotDetails();
    notificationSlotDetails.slotType = notificationDetails.slotType ?? notificationManager.SlotType.UNKNOWN_TYPE;
    notificationSlotDetails.description = notificationDetails.slotDesc;
    notificationSlotDetails.showBadge = notificationDetails.slotShowBadge;
    notificationSlotDetails.importance = notificationDetails.importance;
    notificationSlotDetails.playSound = notificationDetails.playSound;
    notificationSlotDetails.sound = notificationDetails.sound;
    notificationSlotDetails.soundSource = notificationDetails.soundSource;
    notificationSlotDetails.enableVibration = notificationDetails.enableVibration;
    notificationSlotDetails.vibrationPattern = notificationDetails.vibrationPattern;
    notificationSlotDetails.slotAction = notificationDetails.slotAction;
    notificationSlotDetails.enableLights = notificationDetails.enableLights;
    notificationSlotDetails.ledColor = notificationDetails.ledColor;
    notificationSlotDetails.lockscreenVisibility = notificationDetails.lockscreenVisibility;
    notificationSlotDetails.bypassDnd = notificationDetails.bypassDnd;
    return notificationSlotDetails;
  }
}