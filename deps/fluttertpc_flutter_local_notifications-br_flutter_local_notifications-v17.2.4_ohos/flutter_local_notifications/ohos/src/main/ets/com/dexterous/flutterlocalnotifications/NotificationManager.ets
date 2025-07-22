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

import { notificationManager } from '@kit.NotificationKit';
import { bundleManager, UIAbility, wantAgent } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import NotificationDetails from './models/NotificationDetails';
import { notificationContentUtil } from './utils/NotificationContentUtil';
import { BigPictureStyleInformation } from './models/styles/BigPictureStyleInfomation';
import { InBoxStyleInformation } from './models/styles/InBoxStyleInfomation';
import { BigTextStyleInformation } from './models/styles/BigTextStyleInfomation';
import { LiveViewStyleInformation } from './models/styles/LiveViewStyleInformation';
import { DateTimeComponents } from './models/MatchDateTimeComponents';
import { NotificationStyle } from './models/styles/NotificationStyle';
import { RepeatInterval } from './models/RepeatInterval';
import { LocalNotificationsConstants } from './LocalNotificationsConstants';
import NotificationSlotDetails from './models/NotificationSlotDetails';
import { NotificationSlotAction } from './models/NotificationSlotAction';
import { Log } from '@ohos/flutter_ohos';
import { Utils } from './utils/Utils';
import { DefaultStyleInformation } from './models/styles/DefaultStyleInfomation';

const TAG: string = 'FlutterNotificationManager';

class NotificationManager {
  async showNotification(notificationDetails: NotificationDetails): Promise<void> {
    let slotDetails: NotificationSlotDetails = NotificationSlotDetails.fromNotificationDetails(notificationDetails);
    if (await this.canAddNotificationSlot(slotDetails.slotType, slotDetails.slotAction)) {
      // TODO slot当前api12版本只能设置，不能更新
      await this.removeNotificationSlot(slotDetails.slotType);
      await this.addNotificationSlot(slotDetails);
    }
    let notificationContent: notificationManager.NotificationContent | undefined;
    if (notificationDetails.style == NotificationStyle.DefaultStyle) {
      let styleInformation = notificationDetails.styleInformation as DefaultStyleInformation;
      notificationContent = notificationContentUtil.initBasicNotificationContent(styleInformation.htmlFormatTitle ? Utils.fromHtml(notificationDetails.title) : notificationDetails.title,
        styleInformation.htmlFormatBody ? Utils.fromHtml(notificationDetails.body) : notificationDetails.body, notificationDetails.subText) as notificationManager.NotificationContent;
    } else if (notificationDetails.style == NotificationStyle.BigText) {
      let styleInformation = notificationDetails.styleInformation as BigTextStyleInformation;
      notificationContent = notificationContentUtil.initNotificationLongTextContent(styleInformation.htmlFormatTitle ? Utils.fromHtml(notificationDetails.title) : notificationDetails.title,
        styleInformation.htmlFormatBody ? Utils.fromHtml(notificationDetails.body) : notificationDetails.body, styleInformation.htmlFormatContentTitle ? Utils.fromHtml(styleInformation.contentTitle) : styleInformation.contentTitle, styleInformation.htmlFormatSummaryText ? Utils.fromHtml(styleInformation.summaryText) : styleInformation.summaryText,
        styleInformation.htmlFormatBigText ? Utils.fromHtml(styleInformation.bigText) : styleInformation.bigText,
        notificationDetails.subText) as notificationManager.NotificationContent;
    } else if (notificationDetails.style == NotificationStyle.Inbox) {
      let styleInformation = notificationDetails.styleInformation as InBoxStyleInformation;
      let linesNew: Array<string> = [];
      if (styleInformation.htmlFormatLines) {
        for (let line of styleInformation.lines) {
          linesNew.push(Utils.fromHtml(line));
        }
      } else {
        linesNew = styleInformation.lines;
      }
      notificationContent = notificationContentUtil.initNotificationMultiLineContent(styleInformation.htmlFormatTitle ? Utils.fromHtml(notificationDetails.title) : notificationDetails.title,
        styleInformation.htmlFormatBody ? Utils.fromHtml(notificationDetails.body) : notificationDetails.body, styleInformation.htmlFormatContentTitle ? Utils.fromHtml(styleInformation.contentTitle) : styleInformation.contentTitle, styleInformation.htmlFormatSummaryText ? Utils.fromHtml(styleInformation.summaryText) : styleInformation.summaryText,
        linesNew, notificationDetails.subText) as notificationManager.NotificationContent;
    } else if (notificationDetails.style == NotificationStyle.BigPicture) {
      let styleInformation = notificationDetails.styleInformation as BigPictureStyleInformation;
      if (styleInformation.bigPicture && styleInformation.bigPictureSource) {
        let bigPicturePixelMap: image.PixelMap | undefined = await Utils.getPixelMapFromSource(styleInformation.bigPicture,
          styleInformation.bigPictureSource, LocalNotificationsConstants.BIG_PICTURE_HEIGHT, LocalNotificationsConstants.BIG_PICTURE_WIDTH);
        if (bigPicturePixelMap) {
          notificationContent = notificationContentUtil.initNotificationPictureContent(styleInformation.htmlFormatTitle ? Utils.fromHtml(notificationDetails.title) : notificationDetails.title,
            styleInformation.htmlFormatBody ? Utils.fromHtml(notificationDetails.body) : notificationDetails.body, styleInformation.htmlFormatContentTitle ? Utils.fromHtml(styleInformation.contentTitle) : styleInformation.contentTitle, styleInformation.htmlFormatSummaryText ? Utils.fromHtml(styleInformation.summaryText) : styleInformation.summaryText, bigPicturePixelMap,
            notificationDetails.subText) as notificationManager.NotificationContent;
        } else {
          Log.e(TAG, "showNotification-->get bigPicture failed")
        }
      }
    } else if (notificationDetails.style == NotificationStyle.LiveView) {
      let styleInformations = notificationDetails.styleInformation;
      let styleInformation = notificationDetails.styleInformation as LiveViewStyleInformation;
     notificationContent =
        notificationContentUtil.initNotificationSystemLiveViewContent(styleInformation.title, styleInformation.text,
          styleInformation.typeCode, styleInformation.initialTime, styleInformation.isCountDown,
          styleInformation.isPaused, styleInformation.isInTitle) as notificationManager.NotificationContent;
    }
    if (!notificationContent) {
      throw new Error("params check failed");
    }
    let notificationRequest = await this.initBasicNotificationRequest(notificationContent, notificationDetails);
    if (!notificationRequest) {
      throw new Error("notification type not support");
    }
    Log.d(TAG, "showNotification-->request: " + JSON.stringify(notificationRequest));
    let badgeNumber = notificationDetails.badgeNumber;
    notificationManager.publish(notificationRequest, async (err: BusinessError) => {
      if (err?.code) {
        Log.e(TAG, "showNotification-->err code:" + err.code + " message:" + err.message);
      } else {
        if (badgeNumber != undefined) {
          await notificationManager.setBadgeNumber(badgeNumber);
        }
        Log.i(TAG, "showNotification-->success");
      }
    });
  }

  async enableNotification() {
    let enable: boolean = false;
    try {
      await notificationManager.requestEnableNotification();
      enable = true;
      Log.i(TAG, "enableNotification-->success");
    } catch (err) {
      Log.e(TAG, `enableNotification-->err msg: ${JSON.stringify(err)}`);
    }
    return enable
  }

  async isNotificationEnable(): Promise<boolean> {
    let enable: boolean = false;
    try {
      enable = await notificationManager.isNotificationEnabled();
      Log.i(TAG, "isNotificationEnable-->success");
    } catch (err) {
      Log.e(TAG, `isNotificationEnable-->err msg: ${JSON.stringify(err)}`);
    }
    return enable
  }

  async cancelReminderById(notificationId: number) {
    try {
      Log.d(TAG, "cancelReminderById-->notificationId: " + notificationId);
      await reminderAgentManager.cancelReminder(notificationId);
      Log.i(TAG, `cancelReminderById-->success`);
    } catch (err) {
      Log.i(TAG, `cancelReminderById-->err msg: ${JSON.stringify(err)}`);
    }
  }

  async cancelNotificationById(notificationId: number, label: string | undefined) {
    try {
      Log.d(TAG, "cancelNotificationById-->notificationId: " + notificationId + ", tag: " + label);
      await notificationManager.cancel(notificationId, label);
      Log.i(TAG, `cancelNotificationById-->success`);
    } catch (err) {
      Log.i(TAG, `cancelNotificationById-->err msg: ${JSON.stringify(err)}`);
    }
  }

  async cancelAllNotifications() {
    try {
      await notificationManager.cancelAll();
      Log.i(TAG, `cancelAllNotifications-->success`);
    } catch (err) {
      Log.i(TAG, `cancelAllNotifications-->err msg: ${JSON.stringify(err)}`);
    }
  }

  async cancelAllReminders() {
    try {
      await reminderAgentManager.cancelAllReminders();
      Log.i(TAG, `cancelAllReminders-->success`);
    } catch (err) {
      Log.i(TAG, `cancelAllReminders-->err msg: ${JSON.stringify(err)}`);
    }
  }

  async getReminderList(): Promise<Array<reminderAgentManager.ReminderRequest>> {
    let reminders = new Array<reminderAgentManager.ReminderRequest>();
    await reminderAgentManager.getValidReminders().then((data: Array<reminderAgentManager.ReminderRequest>) => {
      reminders = data;
      Log.i(TAG, "getReminderList-->success, data: " + JSON.stringify(data));
    }).catch((err: BusinessError) => {
      Log.e(TAG, "getReminderList-->err msg:" + JSON.stringify(err));
    });
    return reminders;
  }

  async getActiveNotifications(): Promise<Array<notificationManager.NotificationRequest>> {
    let notifications = new Array<notificationManager.NotificationRequest>();
    await notificationManager.getActiveNotifications().then((data: Array<notificationManager.NotificationRequest>) => {
      notifications = data;
      Log.i(TAG, "getActiveNotifications-->success, data: " + JSON.stringify(data));
    }).catch((err: BusinessError) => {
      Log.e(TAG, "getActiveNotifications-->err msg:" + JSON.stringify(err));
    });
    return notifications;
  }

  async publishTimerReminder(notificationDetails: NotificationDetails): Promise<void> {
    let slotDetails: NotificationSlotDetails = NotificationSlotDetails.fromNotificationDetails(notificationDetails);
    if (await this.canAddNotificationSlot(slotDetails.slotType, slotDetails.slotAction)) {
      await this.removeNotificationSlot(slotDetails.slotType);
      await this.addNotificationSlot(slotDetails);
    }
    let triggerTimeInSeconds: number = 0;
    if (notificationDetails.repeatInterval != undefined ||
      notificationDetails.repeatIntervalMilliseconds != undefined) {
      let repeatInterval: number = this.calculateRepeatIntervalMilliseconds(notificationDetails);
      triggerTimeInSeconds = repeatInterval / 1000;
    } else if (notificationDetails.scheduledDateTime) {
      let date: Date = new Date(notificationDetails.scheduledDateTime);
      let currentTime = await systemDateTime.getCurrentTime();
      triggerTimeInSeconds = (date.getTime() - currentTime) / 1000;
    } else {
      Log.e(TAG, "publishTimerReminder-->check time failed");
      return;
    }
    let parameters: Record<string, Object> = {}
    parameters[LocalNotificationsConstants.NOTIFICATION_ID] = notificationDetails?.id ?? "";
    parameters[LocalNotificationsConstants.PAYLOAD] = notificationDetails?.payload ?? "";
    parameters[LocalNotificationsConstants.ACTION] = LocalNotificationsConstants.ACTION_SELECTION_NOTIFICATION;
    let timer: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      wantAgent: {
        pkgName: bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)?.name,
        abilityName: LocalNotificationsConstants.ABILITY_NAME,
        parameters: parameters
      },
      title: (notificationDetails.styleInformation?.htmlFormatTitle ? Utils.fromHtml(notificationDetails.title) : notificationDetails.title) ?? "",
      content: (notificationDetails.styleInformation?.htmlFormatBody ? Utils.fromHtml(notificationDetails.body) : notificationDetails.body) ?? "",
      triggerTimeInSeconds: triggerTimeInSeconds,
    }
    if (notificationDetails.id != undefined) {
      timer.notificationId = notificationDetails.id;
    }
    if (notificationDetails.groupKey) {
      timer.groupId = notificationDetails.groupKey;
    }
    if (notificationDetails.slotType != undefined) {
      timer.slotType = notificationDetails.slotType;
    }
    if (notificationDetails.autoCancel != undefined) {
      timer.tapDismissed = notificationDetails.autoCancel;
    }
    if (notificationDetails.timeoutAfter) {
      timer.autoDeletedTime = await systemDateTime.getCurrentTime(false) + notificationDetails.timeoutAfter;
    }
    Log.d(TAG, "publishTimerReminder-->request: " + JSON.stringify(timer));
    reminderAgentManager.publishReminder(timer, (err: BusinessError, reminderId: number) => {
      if (err?.code) {
        Log.e(TAG, "publishTimerReminder-->err code:" + err.code + " message:" + err.message)
      } else {
        Log.i(TAG, "publishTimerReminder-->success");
      }
    });
  }

  async publishCalendarReminder(notificationDetails: NotificationDetails): Promise<void> {
    let slotDetails: NotificationSlotDetails = NotificationSlotDetails.fromNotificationDetails(notificationDetails);
    if (await this.canAddNotificationSlot(slotDetails.slotType, slotDetails.slotAction)) {
      await this.removeNotificationSlot(slotDetails.slotType);
      await this.addNotificationSlot(slotDetails);
    }
    let date: Date = new Date(notificationDetails.scheduledDateTime ?? "");
    let month = date.getMonth() + 1;
    let parameters: Record<string, Object> = {}
    parameters[LocalNotificationsConstants.NOTIFICATION_ID] = notificationDetails?.id ?? "";
    parameters[LocalNotificationsConstants.PAYLOAD] = notificationDetails?.payload ?? "";
    parameters[LocalNotificationsConstants.ACTION] = LocalNotificationsConstants.ACTION_SELECTION_NOTIFICATION;
    let timer: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      wantAgent: {
        pkgName: bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)?.name,
        abilityName: LocalNotificationsConstants.ABILITY_NAME,
        parameters: parameters
      },
      title: (notificationDetails.styleInformation?.htmlFormatTitle ? Utils.fromHtml(notificationDetails.title) : notificationDetails.title) ?? "",
      content: (notificationDetails.styleInformation?.htmlFormatBody ? Utils.fromHtml(notificationDetails.body) : notificationDetails.body) ?? "",
      dateTime: {
        year: date.getFullYear(),
        month: month,
        day: date.getDate(),
        hour: date.getHours(),
        minute: date.getMinutes(),
        second: date.getSeconds(),
      },
    }
    if (notificationDetails.id != undefined) {
      timer.notificationId = notificationDetails.id;
    }
    if (notificationDetails.groupKey) {
      timer.groupId = notificationDetails.groupKey;
    }
    if (notificationDetails.slotType != undefined) {
      timer.slotType = notificationDetails.slotType;
    }
    if (notificationDetails.autoCancel != undefined) {
      timer.tapDismissed = notificationDetails.autoCancel;
    }
    if (notificationDetails.timeoutAfter) {
      timer.autoDeletedTime = await systemDateTime.getCurrentTime(false) + notificationDetails.timeoutAfter;
    }
    let matchDateTimeComponents: DateTimeComponents | undefined = notificationDetails.matchDateTimeComponents
    if (matchDateTimeComponents != undefined) {
      if (matchDateTimeComponents === DateTimeComponents.Time as DateTimeComponents) {
        let exclude: Map<string, number> = new Map();
        this.calculateRepeatDate(timer, exclude);
      } else if (matchDateTimeComponents === DateTimeComponents.DateAndTime as DateTimeComponents) {
        let exclude: Map<string, number> = new Map();
        exclude.set(LocalNotificationsConstants.DAY, date.getDay())
        this.calculateRepeatDate(timer, exclude);
      } else if (matchDateTimeComponents === DateTimeComponents.DayOfWeekAndTime as DateTimeComponents) {
        let exclude: Map<string, number> = new Map();
        exclude.set(LocalNotificationsConstants.DATE, date.getDate())
        this.calculateRepeatDate(timer, exclude);
      } else if (matchDateTimeComponents === DateTimeComponents.DayOfMonthAndTime as DateTimeComponents) {
        let exclude: Map<string, number> = new Map();
        exclude.set(LocalNotificationsConstants.MONTH, date.getMonth())
        exclude.set(LocalNotificationsConstants.DAY, date.getDay())
        this.calculateRepeatDate(timer, exclude);
      }
    }
    Log.d(TAG, "publishCalendarReminder-->request: " + JSON.stringify(timer));
    reminderAgentManager.publishReminder(timer, (err: BusinessError, reminderId: number) => {
      if (err?.code) {
        Log.e(TAG, "publishCalendarReminder-->err code:" + err.code + " message:" + err.message)
      } else {
        Log.i(TAG, "publishCalendarReminder-->success");
      }
    });
  }

  async addNotificationSlot(notificationSlotDetails: NotificationSlotDetails) {
    this.removeNotificationSlot(notificationSlotDetails.slotType);
    let notificationSlot: notificationManager.NotificationSlot = {
      notificationType: notificationSlotDetails.slotType,
      desc: notificationSlotDetails.description ?? "",
      enabled: true
    };
    if (notificationSlotDetails.importance != undefined) {
      notificationSlot.level = notificationSlotDetails.importance;
    }
    if (notificationSlotDetails.showBadge != undefined) {
      notificationSlot.badgeFlag = notificationSlotDetails.showBadge;
    }
    if (notificationSlotDetails.bypassDnd != undefined) {
      notificationSlot.bypassDnd = notificationSlotDetails.bypassDnd;
    }
    if (notificationSlotDetails.lockscreenVisibility != undefined) {
      notificationSlot.lockscreenVisibility = notificationSlotDetails.lockscreenVisibility ? 2 : 3;
    }
    if (notificationSlotDetails.enableVibration != undefined) {
      notificationSlot.vibrationEnabled = notificationSlotDetails.enableVibration;
    }
    if (notificationSlotDetails.sound) {
      // TODO slot当前api12版本readonly状态，参数暂未处理对接
      notificationSlot.sound = notificationSlotDetails.sound;
    }
    if (notificationSlotDetails.enableLights != undefined) {
      notificationSlot.lightEnabled = notificationSlotDetails.enableLights;
    }
    if (notificationSlotDetails.ledColor != undefined) {
      notificationSlot.lightColor = notificationSlotDetails.ledColor;
    }
    if (notificationSlotDetails.vibrationPattern) {
      notificationSlot.vibrationValues = notificationSlotDetails.vibrationPattern;
    }
    Log.d(TAG, "addNotificationSlot-->request: " + JSON.stringify(notificationSlot));
    reminderAgentManager.addNotificationSlot(notificationSlot, (err: BusinessError) => {
      if (err?.code) {
        Log.e(TAG, "addNotificationSlot-->err code:" + err.code + " message:" + err.message)
      } else {
        Log.i(TAG, "addNotificationSlot-->success");
      }
    });
  }

  async removeNotificationSlot(slotType: number): Promise<void> {
    Log.d(TAG, "removeNotificationSlot-->slotType: " + slotType);
    reminderAgentManager.removeNotificationSlot(slotType,
      (err: BusinessError) => {
        if (err?.code) {
          Log.e(TAG, "removeNotificationSlot-->err code:" + err.code + " message:" + err.message)
        } else {
          Log.i(TAG, "removeNotificationSlot-->success");
        }
      });
  }

  async getAllNotificationSlots(): Promise<Array<notificationManager.NotificationSlot>> {
    let slotList: Array<notificationManager.NotificationSlot> = new Array();
    await notificationManager.getSlots().then((data: Array<notificationManager.NotificationSlot>) => {
      slotList = data;
      Log.i(TAG, "getAllNotificationSlots-->success, data: " + JSON.stringify(data));
    }).catch((err: BusinessError) => {
      Log.e(TAG, "getAllNotificationSlots-->err msg:" + JSON.stringify(err));
    });
    return slotList;
  }

  async getNotificationSlotByType(slotType: number): Promise<notificationManager.NotificationSlot | undefined> {
    let notificationSlot: notificationManager.NotificationSlot | undefined = undefined;
    Log.d(TAG, "getNotificationSlotByType-->slotType: " + slotType);
    await notificationManager.getSlot(slotType).then((data: notificationManager.NotificationSlot) => {
      notificationSlot = data;
      Log.i(TAG, "getNotificationSlotByType-->success, data: " + JSON.stringify(data));
    }).catch((err: BusinessError) => {
      Log.e(TAG, "getNotificationSlotByType-->err msg:" + JSON.stringify(err));
    });
    return notificationSlot;
  }

  private async canAddNotificationSlot(slotType: number, slotAction: NotificationSlotAction | undefined): Promise<boolean> {
    let notificationSlot: notificationManager.NotificationSlot | undefined = await this.getNotificationSlotByType(slotType);
    return ((notificationSlot == undefined
      && (slotAction == undefined
        || slotAction == NotificationSlotAction.CreateIfNotExists))
      || (notificationSlot != undefined
        && slotAction == NotificationSlotAction.Update));
  }

  private async initBasicNotificationRequest(notificationContent: notificationManager.NotificationContent, notificationDetails: NotificationDetails) {
    let actionButtons: Array<notificationManager.NotificationActionButton> = [];
    if (notificationDetails.actions && notificationDetails.actions.length > 0) {
      for (let notificationAction of notificationDetails.actions) {
        let actionItem: notificationManager.NotificationActionButton = {
          title: notificationAction.title ?? "",
          wantAgent: await this.createWantAgentForStartAbility(notificationAction.id, notificationDetails),
        }
        if (notificationAction.actionInputs && notificationAction.actionInputs.length > 0) {
          actionItem.userInput = { inputKey: notificationAction.id ?? "" }
        }
        actionButtons.push(actionItem);
      }
    }
    let result: notificationManager.NotificationRequest = {
      content: notificationContent,
      wantAgent: await this.createWantAgentForStartAbility(undefined, notificationDetails),
      notificationFlags: {
        soundEnabled: notificationDetails.playSound ? 1 : undefined,
        vibrationEnabled: notificationDetails.enableVibration ? 1 : undefined
      }
    }
    if (notificationDetails.id != undefined) {
      result.id = notificationDetails.id;
    }
    if (notificationDetails.slotType != undefined) {
      result.notificationSlotType = notificationDetails.slotType;
    }
    if (notificationDetails.ongoing != undefined) {
      result.isOngoing = notificationDetails.ongoing;
    }
    if (notificationDetails.when) {
      result.deliveryTime = notificationDetails.when;
    }
    if (notificationDetails.autoCancel != undefined) {
      result.tapDismissed = notificationDetails.autoCancel;
    }
    if (notificationDetails.timeoutAfter) {
      result.autoDeletedTime = await systemDateTime.getCurrentTime(false) + notificationDetails.timeoutAfter;
    }
    if (notificationDetails.colorized && notificationDetails.color) {
      result.colorEnabled = notificationDetails.colorized;
      result.color = notificationDetails.color;
    }
    if (notificationDetails.onlyAlertOnce != undefined) {
      result.isAlertOnce = notificationDetails.onlyAlertOnce;
    }
    if (notificationDetails.usesChronometer) {
      result.isStopwatch = !notificationDetails.chronometerCountDown;
      result.isCountDown = notificationDetails.chronometerCountDown;
    }
    if (notificationDetails.isFloatIcon != undefined) {
      result.isFloatingIcon = notificationDetails.isFloatIcon;
    }
    if (notificationDetails.tag) {
      result.label = notificationDetails.tag;
    }
    if (notificationDetails.showWhen != undefined) {
      result.showDeliveryTime = notificationDetails.showWhen;
    }
    if (actionButtons) {
      result.actionButtons = actionButtons;
    }
    let defaultIcon = notificationDetails.icon ? notificationDetails.icon : AppStorage.get(LocalNotificationsConstants.DEFAULT_ICON) as string;
    if (defaultIcon) {
      let uiAbility: UIAbility | undefined = globalThis.context;
      let icon: Uint8Array | undefined = await uiAbility?.context.resourceManager.getMediaByName(defaultIcon);
      if (icon) {
        result.smallIcon = await image.createImageSource(icon.buffer).createPixelMap();
      }
    }
    if (notificationDetails.largeIcon && notificationDetails.largeIconSource != undefined) {
      let largeIcon = await Utils.getPixelMapFromSource(notificationDetails.largeIcon, notificationDetails.largeIconSource, LocalNotificationsConstants.SMALL_ICON_WIDTH, LocalNotificationsConstants.SMALL_ICON_WIDTH);
      if (largeIcon) {
        result.largeIcon = largeIcon;
      } else {
        Log.e(TAG, "initBasicNotificationRequest-->get largeIcon failed")
      }
    }
    // if (notificationDetails.chronometerCountDown && notificationDetails.chronometerCountDown != undefined) {
    //   result.isCountDown = notificationDetails.chronometerCountDown;
    // }
    if (notificationDetails.groupKey) {
      result.groupName = notificationDetails.groupKey;
    }
    if (notificationDetails.showProgress) {
      let isSupportProgress = await notificationManager.isSupportTemplate(LocalNotificationsConstants.NOTIFICATION_TEMPLATE_DOWNLOAD);
      if (!isSupportProgress) {
        return null;
      }
      let progress: number = notificationDetails.progress ?? 0;
      result.template = {
        name: LocalNotificationsConstants.NOTIFICATION_TEMPLATE_DOWNLOAD,
        data: {
          title: (notificationDetails.styleInformation?.htmlFormatTitle ? Utils.fromHtml(notificationDetails.title) : notificationDetails.title) ?? "",
          fileName: (notificationDetails.styleInformation?.htmlFormatBody ? Utils.fromHtml(notificationDetails.body) : notificationDetails.body) ?? "",
          progressValue: progress
        }
      };
    }
    return result;
  }

  private calculateRepeatDate(timer: reminderAgentManager.ReminderRequestCalendar, exclude: Map<String, number>): void {
    timer.repeatMonths = []
    let month = exclude.get(LocalNotificationsConstants.MONTH);
    let date = exclude.get(LocalNotificationsConstants.DATE);
    let day = exclude.get(LocalNotificationsConstants.DAY);
    for (let index = 1; index <= 12; index++) {
      if (index == month) {
        continue;
      }
      timer.repeatMonths.push(index);
    }
    timer.repeatDays = []
    for (let index = 1; index <= 31; index++) {
      if (index == date) {
        continue;
      }
      timer.repeatDays.push(index);
    }
    timer.daysOfWeek = []
    for (let index = 1; index <= 7; index++) {
      if (index == day) {
        continue;
      }
      timer.daysOfWeek.push(index);
    }
  }

  private calculateRepeatIntervalMilliseconds(notificationDetails: NotificationDetails): number {
    let repeatInterval: number = 0;
    switch (notificationDetails.repeatInterval) {
      case RepeatInterval.EveryMinute:
        repeatInterval = 60000;
        break;
      case RepeatInterval.Hourly:
        repeatInterval = 60000 * 60;
        break;
      case RepeatInterval.Daily:
        repeatInterval = 60000 * 60 * 24;
        break;
      case RepeatInterval.Weekly:
        repeatInterval = 60000 * 60 * 24 * 7;
        break;
      default:
        break;
    }
    return repeatInterval;
  }

  private async createWantAgentForStartAbility(actionId?: string, notificationDetails?: NotificationDetails) {
    let parameters: Record<string, Object> = {}
    parameters[LocalNotificationsConstants.NOTIFICATION_ID] = notificationDetails?.id ?? "";
    parameters[LocalNotificationsConstants.ACTION_ID] = actionId ?? "";
    parameters[LocalNotificationsConstants.PAYLOAD] = notificationDetails?.payload ?? "";
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)?.name,
          abilityName: LocalNotificationsConstants.ABILITY_NAME,
          action: LocalNotificationsConstants.ACTION_SELECTION_NOTIFICATION,
          parameters: parameters
        }
      ],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0
    }
    return await wantAgent.getWantAgent(wantAgentInfo);
  }
}

export let notificationManagerApi = new NotificationManager();