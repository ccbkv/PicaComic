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
import { NotificationAction } from './NotificationAction';
import { RepeatInterval } from './RepeatInterval';
import { DateTimeComponents } from './MatchDateTimeComponents';
import { BigTextStyleInformation } from './styles/BigTextStyleInfomation';
import { InBoxStyleInformation } from './styles/InBoxStyleInfomation';
import { LiveViewStyleInformation } from './styles/LiveViewStyleInformation';
import { NotificationStyle } from './styles/NotificationStyle';
import { BigPictureStyleInformation } from './styles/BigPictureStyleInfomation';
import { DefaultStyleInformation } from './styles/DefaultStyleInfomation';
import { SoundSource } from './SoundSource';
import { NotificationSlotAction } from './NotificationSlotAction';
import { PictureSource } from './styles/PictureSource';

export default class NotificationDetails {
  slotType?: number;
  slotDesc?: string;
  slotAction?: NotificationSlotAction;
  slotShowBadge?: boolean;
  importance?: number;
  lockscreenVisibility?: boolean;
  bypassDnd?: boolean;
  id?: number;
  title: string = "";
  body: string = "";
  subText?: string;
  payload?: string;
  repeatInterval?: RepeatInterval;
  repeatIntervalMilliseconds?: number;
  timeZoneName?: string;
  scheduledDateTime?: string;
  matchDateTimeComponents?: DateTimeComponents;
  autoCancel?: boolean;
  ongoing?: boolean;
  onlyAlertOnce?: boolean;
  style?: number;
  styleInformation?: DefaultStyleInformation;
  actions?: Array<NotificationAction>;
  tag?: string;
  groupKey?: string;
  showProgress?: boolean;
  maxProgress?: number;
  progress?: number;
  badgeNumber?: number;
  playSound?: boolean;
  sound?: string;
  // TODO slot当前api12版本readonly状态，参数暂未处理对接
  soundSource?: SoundSource;
  enableVibration?: boolean;
  vibrationPattern?: Array<number>;
  enableLights?: boolean;
  ledColor?: number;
  colorized?: boolean;
  color?: number;

  timeoutAfter?: number;
  showWhen?: boolean;
  when?: number;
  usesChronometer?: boolean;
  chronometerCountDown?: boolean;
  icon?: string;
  isFloatIcon?: boolean;

  largeIcon?: Object;
  largeIconSource?: PictureSource;

  public static from(call: MethodCall): NotificationDetails {
    let notificationDetails: NotificationDetails = new NotificationDetails();
    notificationDetails.title = call.argument(LocalNotificationsConstants.TITLE) ?? "";
    notificationDetails.body = call.argument(LocalNotificationsConstants.BODY) ?? "";
    notificationDetails.id = call.argument(LocalNotificationsConstants.ID);
    notificationDetails.payload = call.argument(LocalNotificationsConstants.PAYLOAD);
    if (call.hasArgument(LocalNotificationsConstants.REPORT_INTERVAL)) {
      notificationDetails.repeatInterval = call.argument(LocalNotificationsConstants.REPORT_INTERVAL);
    }
    if (call.hasArgument(LocalNotificationsConstants.TIMEZONE_NAME)) {
      notificationDetails.timeZoneName = call.argument(LocalNotificationsConstants.TIMEZONE_NAME);
    }
    if (call.hasArgument(LocalNotificationsConstants.SCHEDULED_DATETIME)) {
      notificationDetails.scheduledDateTime = call.argument(LocalNotificationsConstants.SCHEDULED_DATETIME);
    }
    if (call.hasArgument(LocalNotificationsConstants.MATCH_DATETIME_COMPONENTS)) {
      notificationDetails.matchDateTimeComponents = call.argument(LocalNotificationsConstants.MATCH_DATETIME_COMPONENTS);
    }
    if (call.hasArgument(LocalNotificationsConstants.REPEAT_INTERVAL_MILLISECONDS)) {
      notificationDetails.repeatIntervalMilliseconds = call.argument(LocalNotificationsConstants.REPEAT_INTERVAL_MILLISECONDS);
    }
    NotificationDetails.readPlatformSpecifics(call, notificationDetails);
    return notificationDetails;
  }

  private static readPlatformSpecifics(call: MethodCall, notificationDetails: NotificationDetails): void {
    let platformChannelSpecifics: Map<String, Object> = call.argument(LocalNotificationsConstants.PLATFORM_SPECIFICS) as Map<String, Object>;
    if (platformChannelSpecifics) {
      notificationDetails.subText = platformChannelSpecifics.get(LocalNotificationsConstants.SUBTEXT) as (string | undefined);
      notificationDetails.autoCancel = platformChannelSpecifics.get(LocalNotificationsConstants.AUTO_CANCEL) as (boolean | undefined);
      notificationDetails.ongoing = platformChannelSpecifics.get(LocalNotificationsConstants.ONGOING) as (boolean | undefined);
      notificationDetails.onlyAlertOnce = platformChannelSpecifics.get(LocalNotificationsConstants.ONLY_ALERT_ONCE) as (boolean | undefined);

      notificationDetails.showWhen = platformChannelSpecifics.get(LocalNotificationsConstants.SHOW_WHEN) as (boolean | undefined);
      let whenObj = platformChannelSpecifics.get(LocalNotificationsConstants.WHEN) as (number | undefined);
      if (whenObj) {
        notificationDetails.when = Number(whenObj);
      }

      notificationDetails.style = platformChannelSpecifics.get(LocalNotificationsConstants.STYLE) as (number | undefined);
      NotificationDetails.readStyleInformation(platformChannelSpecifics, notificationDetails)

      if (platformChannelSpecifics.has(LocalNotificationsConstants.ACTIONS)) {
        let mapList = platformChannelSpecifics.get(LocalNotificationsConstants.ACTIONS) as Array<Map<string, object>>;
        if (mapList) {
          let actionList: Array<NotificationAction> = [];
          for (let map of mapList) {
            actionList.push(new NotificationAction(map));
          }
          notificationDetails.actions = actionList;
        }
      }

      notificationDetails.tag = platformChannelSpecifics.get(LocalNotificationsConstants.TAG) as (string | undefined);
      notificationDetails.groupKey = platformChannelSpecifics.get(LocalNotificationsConstants.GROUP_KEY) as (string | undefined);
      notificationDetails.slotType = platformChannelSpecifics.get(LocalNotificationsConstants.SLOT_TYPE) as (number | undefined);

      NotificationDetails.readProgressInformation(platformChannelSpecifics, notificationDetails)

      notificationDetails.badgeNumber = platformChannelSpecifics.get(LocalNotificationsConstants.BADGE_NUMBER) as (number | undefined);

      notificationDetails.playSound = platformChannelSpecifics.get(LocalNotificationsConstants.PLAY_SOUND) as (boolean | undefined);
      notificationDetails.sound = platformChannelSpecifics.get(LocalNotificationsConstants.SOUND) as (string | undefined);
      notificationDetails.soundSource = platformChannelSpecifics.get(LocalNotificationsConstants.SOUND_SOURCE) as (number | undefined);

      notificationDetails.enableVibration = platformChannelSpecifics.get(LocalNotificationsConstants.ENABLE_VIBRATION) as (boolean | undefined);
      notificationDetails.vibrationPattern = platformChannelSpecifics.get(LocalNotificationsConstants.VIBRATION_PATTERN) as (Array<number> | undefined);
      notificationDetails.enableLights = platformChannelSpecifics.get(LocalNotificationsConstants.ENABLE_LIGHTS) as (boolean | undefined);
      notificationDetails.colorized = platformChannelSpecifics.get(LocalNotificationsConstants.COLORIZED) as (boolean | undefined);
      let alpha: number | undefined = platformChannelSpecifics.get(LocalNotificationsConstants.LED_COLOR_ALPHA) as (number | undefined);
      let red: number | undefined = platformChannelSpecifics.get(LocalNotificationsConstants.LED_COLOR_RED) as (number | undefined);
      let green: number | undefined = platformChannelSpecifics.get(LocalNotificationsConstants.LED_COLOR_GREEN) as (number | undefined);
      let blue: number | undefined = platformChannelSpecifics.get(LocalNotificationsConstants.LED_COLOR_BLUE) as (number | undefined);
      if (alpha != undefined && red!= undefined && green!= undefined && blue!= undefined) {
        alpha = Math.max(0, Math.min(255, alpha));
        red = Math.max(0, Math.min(255, red));
        green = Math.max(0, Math.min(255, green));
        blue = Math.max(0, Math.min(255, blue));

        let color: number = (alpha << 24) | (red << 16) | (green << 8) | blue;
        if (color < 0) {
          color = 0xFFFFFFFF + color + 1;
        }
        // TODO暂未支持
        // notificationDetails.color = color;
      }
      let silent = platformChannelSpecifics.get(LocalNotificationsConstants.SILENT) as (boolean | undefined);
      if (silent) {
        notificationDetails.playSound = false;
        notificationDetails.enableVibration = false;
        notificationDetails.enableLights = false;
      }
      notificationDetails.timeoutAfter = platformChannelSpecifics.get(LocalNotificationsConstants.TIMEOUT_AFTER) as (number | undefined);
      notificationDetails.usesChronometer = platformChannelSpecifics.get(LocalNotificationsConstants.USES_CHRONOMETER) as (boolean | undefined);
      notificationDetails.chronometerCountDown = platformChannelSpecifics.get(LocalNotificationsConstants.CHRONOMETER_COUNTDOWN) as (boolean | undefined);
      notificationDetails.icon = platformChannelSpecifics.get(LocalNotificationsConstants.ICON) as (string | undefined);
      notificationDetails.slotType = platformChannelSpecifics.get(LocalNotificationsConstants.SLOT_TYPE) as (number | undefined);
      notificationDetails.slotDesc = platformChannelSpecifics.get(LocalNotificationsConstants.SLOT_DESC) as (string | undefined);
      notificationDetails.slotAction = platformChannelSpecifics.get(LocalNotificationsConstants.SLOT_ACTION) as (number | undefined);
      notificationDetails.slotShowBadge = platformChannelSpecifics.get(LocalNotificationsConstants.SLOT_SHOW_BADGE) as (boolean | undefined);
      notificationDetails.importance = platformChannelSpecifics.get(LocalNotificationsConstants.IMPORTANCE) as (number | undefined);
      notificationDetails.lockscreenVisibility = platformChannelSpecifics.get(LocalNotificationsConstants.LOCKSCREEN_VISIBILITY) as (boolean | undefined);
      notificationDetails.bypassDnd = platformChannelSpecifics.get(LocalNotificationsConstants.BYPASSDND) as (boolean | undefined);
      notificationDetails.isFloatIcon = platformChannelSpecifics.get(LocalNotificationsConstants.IS_FLOAT_ICON) as (boolean | undefined);
      notificationDetails.largeIcon = platformChannelSpecifics.get(LocalNotificationsConstants.LARGE_ICON);
      notificationDetails.largeIconSource = platformChannelSpecifics.get(LocalNotificationsConstants.LARGE_ICON_SOURCE) as (number | undefined);
    }
  }

  private static readStyleInformation(platformChannelSpecifics: Map<String, Object>, notificationDetails: NotificationDetails): void {
    let styleInformation: Map<String, Object> = platformChannelSpecifics.get(LocalNotificationsConstants.STYLE_INFORMATION) as Map<String, Object>;
    if (styleInformation) {
      let defaultStyleInformation: DefaultStyleInformation = NotificationDetails.getDefaultStyleInformation(styleInformation);
      if (notificationDetails.style == NotificationStyle.DefaultStyle) {
        notificationDetails.styleInformation = defaultStyleInformation;
      } else if (notificationDetails.style == NotificationStyle.BigPicture) {
        NotificationDetails.readBigPictureStyleInformation(notificationDetails, styleInformation, defaultStyleInformation);
      } else if (notificationDetails.style == NotificationStyle.BigText) {
        NotificationDetails.readBigTextStyleInformation(notificationDetails, styleInformation, defaultStyleInformation);
      } else if (notificationDetails.style == NotificationStyle.Inbox) {
        NotificationDetails.readInboxStyleInformation(notificationDetails, styleInformation, defaultStyleInformation);
      } else if (notificationDetails.style == NotificationStyle.LiveView) {
        NotificationDetails.readLiveViewStyleInformation(notificationDetails, styleInformation, defaultStyleInformation);
      }
    }
  }

  private static readLiveViewStyleInformation(notificationDetails: NotificationDetails, styleInformation: Map<String, Object>, defaultStyleInformation: DefaultStyleInformation): void {
    let title = styleInformation.get("title") as (string | undefined) ?? 'title';
    let text = styleInformation.get("text") as (string | undefined) ?? "text";
    let typeCode = styleInformation.get("typeCode") as (number | undefined) ?? 0;
    let initialTime = styleInformation.get("initialTime") as (number | undefined) ?? 3000;

    let isCountDown = styleInformation.get("isCountDown") as (boolean | undefined) ?? false;
    let isPaused = styleInformation.get("isPaused") as (boolean | undefined) ?? false;
    let isInTitle = styleInformation.get("isInTitle") as (boolean | undefined) ?? false;
    notificationDetails.styleInformation =
      new LiveViewStyleInformation(defaultStyleInformation.htmlFormatTitle, defaultStyleInformation.htmlFormatBody,
        title, text, typeCode,initialTime,isCountDown, isPaused, isInTitle);
  }

  private static getDefaultStyleInformation(styleInformation: Map<String, Object>): DefaultStyleInformation {
    let htmlFormatTitle = (styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_TITLE) as (boolean | undefined)) ?? false;
    let htmlFormatBody = (styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_CONTENT) as (boolean | undefined)) ?? false;
    return new DefaultStyleInformation(htmlFormatTitle, htmlFormatBody);
  }

  private static readBigPictureStyleInformation(notificationDetails: NotificationDetails, styleInformation: Map<String, Object>, defaultStyleInformation: DefaultStyleInformation): void {
    let contentTitle = styleInformation.get(LocalNotificationsConstants.CONTENT_TITLE) as (string | undefined);
    let summaryText = styleInformation.get(LocalNotificationsConstants.SUMMARY_TEXT) as (string | undefined);
    let bigPicture = styleInformation.get(LocalNotificationsConstants.BIG_PICTURE);
    let bigPictureSource = styleInformation.get(LocalNotificationsConstants.BIG_PICTURE_SOURCE) as (number | undefined);
    if (!contentTitle || !summaryText || !bigPicture || !bigPictureSource) {
      return;
    }
    let htmlFormatContentTitle = styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_CONTENT_TITLE) as (boolean | undefined) ?? false;
    let htmlFormatSummaryText = styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_SUMMARY_TEXT) as (boolean | undefined) ?? false;
    notificationDetails.styleInformation = new BigPictureStyleInformation(defaultStyleInformation.htmlFormatTitle, defaultStyleInformation.htmlFormatBody, contentTitle, summaryText, htmlFormatContentTitle, htmlFormatSummaryText, bigPicture, bigPictureSource);
  }

  private static readBigTextStyleInformation(notificationDetails: NotificationDetails, styleInformation: Map<String, Object>, defaultStyleInformation: DefaultStyleInformation): void {
    let contentTitle = styleInformation.get(LocalNotificationsConstants.CONTENT_TITLE) as (string | undefined);
    let bigText = styleInformation.get(LocalNotificationsConstants.BIG_TEXT) as (string | undefined);
    let summaryText = styleInformation.get(LocalNotificationsConstants.SUMMARY_TEXT) as (string | undefined);
    if (!contentTitle || !bigText || !summaryText) {
      return;
    }
    let htmlFormatContentTitle = styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_CONTENT_TITLE) as (boolean | undefined) ?? false;
    let htmlFormatSummaryText = styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_SUMMARY_TEXT) as (boolean | undefined) ?? false;
    let htmlFormatBigText = styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_BIG_TEXT) as (boolean | undefined) ?? false;
    notificationDetails.styleInformation = new BigTextStyleInformation(defaultStyleInformation.htmlFormatTitle, defaultStyleInformation.htmlFormatBody, contentTitle, bigText, summaryText, htmlFormatContentTitle, htmlFormatSummaryText, htmlFormatBigText);
  }

  private static readInboxStyleInformation(notificationDetails: NotificationDetails, styleInformation: Map<String, Object>, defaultStyleInformation: DefaultStyleInformation): void {
    let contentTitle = styleInformation.get(LocalNotificationsConstants.CONTENT_TITLE) as (string | undefined);
    let lines = styleInformation.get(LocalNotificationsConstants.TEXT_LINES) as (Array<string> | undefined);
    let summaryText = styleInformation.get(LocalNotificationsConstants.SUMMARY_TEXT) as (string | undefined);
    if (!contentTitle || !lines || !summaryText) {
      return;
    }
    let htmlFormatContentTitle = styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_CONTENT_TITLE) as (boolean | undefined) ?? false;
    let htmlFormatSummaryText = styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_SUMMARY_TEXT) as (boolean | undefined) ?? false;
    let htmlFormatLines = styleInformation.get(LocalNotificationsConstants.HTML_FORMAT_LINES) as (boolean | undefined) ?? false;
    notificationDetails.styleInformation = new InBoxStyleInformation(defaultStyleInformation.htmlFormatTitle, defaultStyleInformation.htmlFormatBody, contentTitle, lines, summaryText, htmlFormatContentTitle, htmlFormatSummaryText, htmlFormatLines);
  }

  private static readProgressInformation(platformChannelSpecifics: Map<String, Object>, notificationDetails: NotificationDetails): void {
    notificationDetails.showProgress = platformChannelSpecifics.get(LocalNotificationsConstants.SHOW_PROGRESS) as (boolean | undefined);
    if (platformChannelSpecifics.has(LocalNotificationsConstants.MAX_PROGRESS)) {
      notificationDetails.maxProgress = platformChannelSpecifics.get(LocalNotificationsConstants.MAX_PROGRESS) as number;
    }
    if (platformChannelSpecifics.has(LocalNotificationsConstants.PROGRESS)) {
      notificationDetails.progress = platformChannelSpecifics.get(LocalNotificationsConstants.PROGRESS) as number;
    }
  }
}