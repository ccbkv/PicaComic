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

import { Log, MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { LocalNotificationsConstants } from './LocalNotificationsConstants';
import { notificationManager } from '@kit.NotificationKit';
import NotificationDetails from './models/NotificationDetails';
import Want from '@ohos.app.ability.Want';
import systemDateTime from '@ohos.systemDateTime';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import UIAbility from '@ohos.app.ability.UIAbility';
import { notificationManagerApi } from './NotificationManager';
import NotificationSlotDetails from './models/NotificationSlotDetails';
import abilityFeature from '@ohos.ability.featureAbility';
// import permission from '@ohos.security.permission';

const TAG: string = 'FlutterMethodCallHandlerImpl';

export default class MethodCallHandlerImpl implements MethodCallHandler {
  private launchWant?: Want;

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case LocalNotificationsConstants.INITIALIZE_METHOD:
        this.initialize(call, result);
        break;
      case LocalNotificationsConstants.GET_NOTIFICATION_APP_LAUNCH_DETAILS_METHOD:
        this.getNotificationAppLaunchDetails(result);
        break;
      case LocalNotificationsConstants.ARE_NOTIFICATIONS_ENABLED_METHOD:
        this.isNotificationEnable(result);
        break;
      case LocalNotificationsConstants.REQUEST_NOTIFICATIONS_PERMISSION_METHOD:
        this.requestNotificationsPermission(result);
        break;
      case LocalNotificationsConstants.GET_ACTIVE_NOTIFICATIONS_METHOD:
        this.getActiveNotifications(result);
        break;
      case LocalNotificationsConstants.SHOW_METHOD:
        this.show(call, result);
        break;
      case LocalNotificationsConstants.CANCEL_METHOD:
        this.cancel(call, result);
        break;
      case LocalNotificationsConstants.CANCEL_ALL_METHOD:
        this.cancelAllNotifications(result);
        break;
      case LocalNotificationsConstants.PENDING_NOTIFICATION_REQUESTS_METHOD:
        this.getScheduledNotifications(result);
        break;
      case LocalNotificationsConstants.PERIODICALLY_SHOW_METHOD:
        this.repeat(call, result);
        break;
      case LocalNotificationsConstants.PERIODICALLY_SHOW_WITH_DURATION_METHOD:
        this.repeat(call, result);
        break;
      case LocalNotificationsConstants.ZONED_SCHEDULE_METHOD:
        this.zonedSchedule(call, result);
        break;
      case LocalNotificationsConstants.ADD_NOTIFICATION_SLOT_METHOD:
        this.addNotificationSlot(call, result);
        break;
      case LocalNotificationsConstants.DELETE_NOTIFICATION_SLOT_METHOD:
        this.deleteNotificationSlot(call, result);
        break;
      case LocalNotificationsConstants.GET_NOTIFICATION_SLOT_METHOD:
        this.getNotificationSlots(result);
        break;
      case LocalNotificationsConstants.GET_LOCAL_TIMEZONE:
        result.success(systemDateTime.getTimezoneSync());
        break;
      case LocalNotificationsConstants.REQUEST_FULL_SCREEN_INTENT_PERMISSION_METHOD:
        this.requestFullScreenIntentPermission(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  initLaunchWant(launchWant: Want | undefined): void {
    Log.d(TAG, "initLaunchWant--> want: " + JSON.stringify(launchWant));
    this.launchWant = launchWant;
  }

  onNewWant(want: Want, channel: MethodChannel): void {
    Log.d(TAG, "onNewWant--> want: " + JSON.stringify(want));
    if (want?.action === LocalNotificationsConstants.ACTION_SELECTION_NOTIFICATION || (want.parameters != undefined && want.parameters[LocalNotificationsConstants.ACTION] == LocalNotificationsConstants.ACTION_SELECTION_NOTIFICATION)) {
      channel.invokeMethod(LocalNotificationsConstants.RECEIVE_NOTIFICATION_RESPONSE, this.extractNotificationResponseMap(want));
    }
  }

  private requestFullScreenIntentPermission(call: MethodCall, result: MethodResult) {

  }

  private extractNotificationResponseMap(want: Want | undefined): Map<string, object> {
    let map: Map<string, Object> = new Map<string, object>();
    if (!want) {
      return map
    }
    let parameters: Record<string, Object> | undefined = want.parameters;
    if (parameters) {
      map.set(LocalNotificationsConstants.NOTIFICATION_ID, parameters[LocalNotificationsConstants.NOTIFICATION_ID]);
      map.set(LocalNotificationsConstants.NOTIFICATION_TAG, parameters[LocalNotificationsConstants.NOTIFICATION_TAG]);
      map.set(LocalNotificationsConstants.ACTION_ID, parameters[LocalNotificationsConstants.ACTION_ID]);
      map.set(LocalNotificationsConstants.PAYLOAD, parameters[LocalNotificationsConstants.PAYLOAD]);
      if (parameters[LocalNotificationsConstants.KEY]) {
        map.set(LocalNotificationsConstants.INPUT, parameters[LocalNotificationsConstants.DATA]);
      }
      map.set(LocalNotificationsConstants.NOTIFICATION_RESPONSE_TYPE, 0);
    }
    return map;
  }

  private async initialize(call: MethodCall, result: MethodResult): Promise<void> {
    let defaultIcon: string = call.argument(LocalNotificationsConstants.DEFAULT_ICON);
    Log.d(TAG, "initialize-->defaultIcon set defaultIcon: " + defaultIcon);
    if (!defaultIcon) {
      Log.w(TAG, "initialize-->defaultIcon not seted");
      result.success(true);
      return
    }
    try {
      let uiAbility: UIAbility | undefined = globalThis.context;
      let icon: Uint8Array | undefined = await uiAbility?.context.resourceManager.getMediaByName(defaultIcon);
      if (icon) {
        PersistentStorage.persistProp(LocalNotificationsConstants.DEFAULT_ICON, defaultIcon);
        Log.i(TAG, "initialize-->defaultIcon seted");
      } else {
        Log.i(TAG, "initialize-->defaultIcon get failed");
      }
    } catch (e) {
      Log.e(TAG, "initialize-->err msg: " + JSON.stringify(e));
    }
    result.success(true);
  }

  private getNotificationAppLaunchDetails(result: MethodResult): void {
    let notificationLaunchedApp: boolean = this.launchWant != undefined && (this.launchWant.action === LocalNotificationsConstants.ACTION_SELECTION_NOTIFICATION || (this.launchWant.parameters != undefined && this.launchWant.parameters[LocalNotificationsConstants.ACTION] == LocalNotificationsConstants.ACTION_SELECTION_NOTIFICATION));
    let notificationAppLaunchDetails: Map<string, Object> = new Map<string, Object>();
    if (notificationLaunchedApp) {
      notificationAppLaunchDetails.set(LocalNotificationsConstants.NOTIFICATION_RESPONSE, this.extractNotificationResponseMap(this.launchWant));
    }
    Log.i(TAG, "getNotificationAppLaunchDetails-->LaunchedApp from notification: " + notificationLaunchedApp);
    notificationAppLaunchDetails.set(LocalNotificationsConstants.NOTIFICATION_LAUNCHED_APP, notificationLaunchedApp);
    Log.d(TAG, "getNotificationAppLaunchDetails-->data: " + JSON.stringify(notificationAppLaunchDetails));
    result.success(notificationAppLaunchDetails);
  }

  private async show(call: MethodCall, result: MethodResult): Promise<void> {
    let notificationDetails: NotificationDetails = NotificationDetails.from(call)
    if (!notificationDetails.title || !notificationDetails.body) {
      result.error("-1", "title or body cannot be empty", "");
      Log.e(TAG, "show-->title or body cannot be empty");
      return;
    }
    try {
      Log.d(TAG, "show-->request: " + JSON.stringify(notificationDetails));
      await notificationManagerApi.showNotification(notificationDetails);
      result.success(null);
    } catch (e) {
      result.error("-1", e, "");
      Log.e(TAG, "show-->err msg: " + JSON.stringify(e));
    }
  }

  private zonedSchedule(call: MethodCall, result: MethodResult): void {
    let notificationDetails: NotificationDetails = NotificationDetails.from(call)
    if (!notificationDetails.title || !notificationDetails.body) {
      result.error("-1", "title or body cannot be empty", "")
      return;
    }
    Log.d(TAG, "zonedSchedule-->request: " + JSON.stringify(notificationDetails));
    if (notificationDetails.matchDateTimeComponents == undefined) {
      notificationManagerApi.publishTimerReminder(notificationDetails)
    } else {
      notificationManagerApi.publishCalendarReminder(notificationDetails);
    }
    result.success(null);
  }

  private async requestNotificationsPermission(result: MethodResult): Promise<void> {
    let enable: boolean = await notificationManagerApi.enableNotification();
    result.success(enable);
  }

  private async repeat(call: MethodCall, result: MethodResult): Promise<void> {
    let notificationDetails: NotificationDetails = NotificationDetails.from(call);
    Log.d(TAG, "repeat-->request: " + JSON.stringify(notificationDetails));
    notificationManagerApi.publishTimerReminder(notificationDetails)
    result.success(null);
  }

  private async repeatWithDuration(call: MethodCall, result: MethodResult): Promise<void> {
    let notificationDetails: NotificationDetails = NotificationDetails.from(call);
    Log.d(TAG, "repeatWithDuration-->repeatWithDuration: " + JSON.stringify(notificationDetails));
    notificationManagerApi.publishTimerReminder(notificationDetails)
    result.success(null);
  }

  private async cancel(call: MethodCall, result: MethodResult): Promise<void> {
    let notificationId: number = call.argument(LocalNotificationsConstants.ID);
    notificationManagerApi.cancelNotificationById(notificationId, call.argument(LocalNotificationsConstants.TAG));
    let reminderList: Array<reminderAgentManager.ReminderInfo> = await reminderAgentManager.getAllValidReminders();
    if (reminderList && reminderList.length > 0) {
      for (let index = 0; index < reminderList.length; index++) {
        let reminderInfo: reminderAgentManager.ReminderInfo = reminderList[index];
        // TODO getAllValidReminders获取reminderInfo-notificationId与初始设置不一致，暂不支持取消
        if (reminderInfo && reminderInfo.reminderReq?.notificationId === notificationId) {
          let reminderId = reminderInfo.reminderId;
          notificationManagerApi.cancelReminderById(reminderId);
          break;
        }
      }
    }
    result.success(null);
  }

  private cancelAllNotifications(result: MethodResult): void {
    notificationManagerApi.cancelAllNotifications();
    notificationManagerApi.cancelAllReminders();
    result.success(null);
  }

  private async getScheduledNotifications(result: MethodResult): Promise<void> {
    Log.d(TAG, "getScheduledNotifications-->request: ");
    let scheduledNotifications: Array<reminderAgentManager.ReminderRequest> = await notificationManagerApi.getReminderList();
    if (scheduledNotifications) {
      let pendingNotifications: Array<Map<string, Object>> = new Array<Map<string, Object>>();
      for (let scheduledNotification of scheduledNotifications) {
        let pendingNotification: Map<string, Object> = new Map();
        pendingNotification.set(LocalNotificationsConstants.ID, scheduledNotification.notificationId ?? "");
        pendingNotification.set(LocalNotificationsConstants.TITLE, scheduledNotification.title ?? "");
        pendingNotification.set(LocalNotificationsConstants.BODY, scheduledNotification.content ?? "");
        // TODO 当前api12版本，暂不支持该字段读取
        // pendingNotification.set("payload", scheduledNotification.payload??"");
        pendingNotifications.push(pendingNotification);
      }
      Log.d(TAG, "getScheduledNotifications-->data: " + JSON.stringify(pendingNotifications));
      result.success(pendingNotifications);
      return;
    }
    Log.d(TAG, "getScheduledNotifications-->data: empty");
    result.success(null);
  }

  private async isNotificationEnable(result: MethodResult): Promise<void> {
    let enable = await notificationManagerApi.isNotificationEnable()
    result.success(enable);
  }

  private async getActiveNotifications(result: MethodResult): Promise<void> {
    Log.d(TAG, "getActiveNotifications-->request: ");
    let activeNotifications: Array<notificationManager.NotificationRequest> = await notificationManagerApi.getActiveNotifications();
    if (!activeNotifications) {
      Log.d(TAG, "getActiveNotifications-->data: empty");
      result.success(null)
      return
    }
    let activeNotificationsList: Array<Map<String, Object>> = new Array();
    for (let notification of activeNotifications) {
      let map: Map<String, Object | Number> = new Map();
      map.set(LocalNotificationsConstants.ID, notification.id ?? 0)
      map.set(LocalNotificationsConstants.TAG, notification.label ?? "")
      map.set(LocalNotificationsConstants.GROUP_KEY, notification.groupName ?? "")
      map.set(LocalNotificationsConstants.TITLE, notification.content?.normal?.title ?? "")
      map.set(LocalNotificationsConstants.BODY, notification.content?.normal?.text ?? "")
      activeNotificationsList.push(map)
    }
    Log.d(TAG, "getActiveNotifications-->data: " + JSON.stringify(activeNotificationsList));
    result.success(activeNotificationsList);
  }

  private async addNotificationSlot(call: MethodCall, result: MethodResult): Promise<void> {
    let notificationSlotDetails = NotificationSlotDetails.from(call);
    Log.d(TAG, "addNotificationSlot-->request: " + JSON.stringify(notificationSlotDetails));
    await notificationManagerApi.addNotificationSlot(notificationSlotDetails);
    result.success(true);
  }

  private async deleteNotificationSlot(call: MethodCall, result: MethodResult): Promise<void> {
    await notificationManagerApi.removeNotificationSlot(call.args);
    result.success(true);
  }

  private async getNotificationSlots(result: MethodResult): Promise<void> {
    Log.d(TAG, "getNotificationSlots-->request: ");
    let notificationSlots: Array<notificationManager.NotificationSlot> = await notificationManagerApi.getAllNotificationSlots();
    let activeNotificationsList: Array<Map<String, Object>> = new Array();
    for (let notificationSlot of notificationSlots) {
      let map: Map<String, Object | Number> = new Map();
      map.set(LocalNotificationsConstants.SLOT_TYPE, notificationSlot.notificationType ?? notificationManager.SlotType.UNKNOWN_TYPE);
      map.set(LocalNotificationsConstants.DESCRIPTION, notificationSlot.desc ?? "");
      map.set(LocalNotificationsConstants.SHOW_BADGE, notificationSlot.badgeFlag ?? false);
      map.set(LocalNotificationsConstants.IMPORTANCE, notificationSlot.level ?? "");
      map.set(LocalNotificationsConstants.PLAY_SOUND, notificationSlot.sound != null);
      map.set(LocalNotificationsConstants.SOUND, notificationSlot.sound ?? "");
      map.set(LocalNotificationsConstants.ENABLE_VIBRATION, notificationSlot.vibrationEnabled ?? false);
      map.set(LocalNotificationsConstants.VIBRATION_PATTERN, notificationSlot.vibrationValues ?? []);
      map.set(LocalNotificationsConstants.ENABLE_LIGHTS, notificationSlot.lightEnabled ?? false);
      map.set(LocalNotificationsConstants.LED_COLOR, notificationSlot.lightColor ?? -1);
      activeNotificationsList.push(map);
    }
    Log.d(TAG, "getNotificationSlots-->data: " + JSON.stringify(activeNotificationsList));
    result.success(activeNotificationsList);
  }
}
