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

export class LocalNotificationsConstants {
  static INITIALIZE_METHOD = "initialize";
  static GET_CALLBACK_HANDLE_METHOD = "getCallbackHandle";
  static ARE_NOTIFICATIONS_ENABLED_METHOD = "areNotificationsEnabled";
  static CAN_SCHEDULE_EXACT_NOTIFICATIONS_METHOD = "canScheduleExactNotifications";
  static CREATE_NOTIFICATION_CHANNEL_GROUP_METHOD = "createNotificationChannelGroup";
  static DELETE_NOTIFICATION_CHANNEL_GROUP_METHOD = "deleteNotificationChannelGroup";
  static CREATE_NOTIFICATION_CHANNEL_METHOD = "createNotificationChannel";
  static DELETE_NOTIFICATION_CHANNEL_METHOD = "deleteNotificationChannel";
  static GET_ACTIVE_NOTIFICATION_MESSAGING_STYLE_METHOD = "getActiveNotificationMessagingStyle";
  static GET_NOTIFICATION_CHANNELS_METHOD = "getNotificationChannels";
  static START_FOREGROUND_SERVICE = "startForegroundService";
  static STOP_FOREGROUND_SERVICE = "stopForegroundService";
  static PENDING_NOTIFICATION_REQUESTS_METHOD = "pendingNotificationRequests";
  static GET_ACTIVE_NOTIFICATIONS_METHOD = "getActiveNotifications";
  static SHOW_METHOD = "show";
  static CANCEL_METHOD = "cancel";
  static CANCEL_ALL_METHOD = "cancelAll";
  static ZONED_SCHEDULE_METHOD = "zonedSchedule";
  static PERIODICALLY_SHOW_METHOD = "periodicallyShow";
  static PERIODICALLY_SHOW_WITH_DURATION_METHOD = "periodicallyShowWithDuration";
  static GET_NOTIFICATION_APP_LAUNCH_DETAILS_METHOD = "getNotificationAppLaunchDetails";
  static REQUEST_NOTIFICATIONS_PERMISSION_METHOD = "requestNotificationsPermission";
  static REQUEST_EXACT_ALARMS_PERMISSION_METHOD = "requestExactAlarmsPermission";
  static REQUEST_FULL_SCREEN_INTENT_PERMISSION_METHOD = "requestFullScreenIntentPermission";
  static RECEIVE_NOTIFICATION_RESPONSE = "didReceiveNotificationResponse";
  static GET_LOCAL_TIMEZONE = "getLocalTimezone";
  static ADD_NOTIFICATION_SLOT_METHOD = "addNotificationSlot";
  static DELETE_NOTIFICATION_SLOT_METHOD = "deleteNotificationSlot";
  static GET_NOTIFICATION_SLOT_METHOD = "getNotificationSlots";

  static ID = "id";
  static TITLE = "title";
  static BODY = "body";
  static INPUTS = "inputs";
  static PAYLOAD = "payload";
  static ACTION = "action";
  static REPORT_INTERVAL = "repeatInterval";
  static REPEAT_INTERVAL_MILLISECONDS = "repeatIntervalMilliseconds";
  static TIMEZONE_NAME = "timeZoneName";
  static SCHEDULED_DATETIME = "scheduledDateTime";
  static MATCH_DATETIME_COMPONENTS = "matchDateTimeComponents";
  static PLATFORM_SPECIFICS = "platformSpecifics";
  static SUBTEXT = "subText";
  static AUTO_CANCEL = "autoCancel";
  static ONGOING = "ongoing";
  static ONLY_ALERT_ONCE = "onlyAlertOnce";
  static SHOW_WHEN = "showWhen";
  static WHEN = "when";
  static STYLE = "style";
  static ACTIONS = "actions";
  static TAG = "tag";
  static GROUP_KEY = "groupKey";
  static SLOT_TYPE = "slotType";
  static BADGE_NUMBER = "badgeNumber";
  static PLAY_SOUND = "playSound";
  static ENABLE_VIBRATION = "enableVibration";
  static SILENT = "silent";
  static STYLE_INFORMATION = "styleInformation";
  static HTML_FORMAT_TITLE = "htmlFormatTitle";
  static HTML_FORMAT_CONTENT = "htmlFormatContent";
  static CONTENT_TITLE = "contentTitle";
  static SUMMARY_TEXT = "summaryText";
  static LARGE_ICON = "largeIcon";
  static LARGE_ICON_SOURCE = "largeIconBitmapSource";
  static BIG_PICTURE = "bigPicture";
  static BIG_PICTURE_SOURCE = "bigPictureBitmapSource";
  static BIG_TEXT = "bigText";
  static TEXT_LINES = "lines";
  static SHOW_PROGRESS = "showProgress";
  static MAX_PROGRESS = "maxProgress";
  static PROGRESS = "progress";
  static ACTION_SELECTION_NOTIFICATION = "SELECT_NOTIFICATION";
  static TIMEOUT_AFTER = "timeoutAfter";
  static USES_CHRONOMETER = "usesChronometer";
  static CHRONOMETER_COUNTDOWN = "chronometerCountDown";
  static FULL_SCREEN = "fullScreenIntent";
  static ICON = "icon";
  static SLOT_DESC = "slotDesc";
  static SLOT_SHOW_BADGE = "slotShowBadge";

  static HTML_FORMAT_CONTENT_TITLE = "htmlFormatContentTitle";
  static HTML_FORMAT_SUMMARY_TEXT = "htmlFormatSummaryText";
  static HTML_FORMAT_BIG_TEXT = "htmlFormatBigText";
  static HTML_FORMAT_LINES = "htmlFormatLines";

  static DESCRIPTION = "description";
  static SHOW_BADGE = "showBadge";
  static IMPORTANCE = "importance";
  static SLOT_ACTION = "slotAction";
  static LOCKSCREEN_VISIBILITY = "lockscreenVisibility";
  static BYPASSDND = "bypassDnd";
  static SOUND = "sound";
  static SOUND_SOURCE = "soundSource";
  static VIBRATION_PATTERN = "vibrationPattern";
  static IS_FLOAT_ICON = "isFloatingIcon";

  static COLORIZED = "colorized";
  static ENABLE_LIGHTS = "enableLights";
  static LED_COLOR_ALPHA = "ledColorAlpha";
  static LED_COLOR_RED = "ledColorRed";
  static LED_COLOR_GREEN = "ledColorGreen";
  static LED_COLOR_BLUE = "ledColorBlue";
  static LED_COLOR = "ledColor";


  static NOTIFICATION_ID = "notificationId";
  static NOTIFICATION_TAG = "notificationTag";
  static ACTION_ID = "actionId";
  static KEY = "key";
  static INPUT = "input";
  static DATA = "data";
  static NOTIFICATION_RESPONSE_TYPE = "notificationResponseType";

  static DEFAULT_ICON = "defaultIcon";
  static NOTIFICATION_RESPONSE = "notificationResponse";
  static NOTIFICATION_LAUNCHED_APP = "notificationLaunchedApp";

  static ABILITY_NAME = "EntryAbility";
  static DAY = "day";
  static DATE = "date";
  static MONTH = "month";
  static NOTIFICATION_TEMPLATE_DOWNLOAD = "downloadTemplate";

  static LARGE_ICON_WIDTH = 64;
  static SMALL_ICON_WIDTH = 48;
  static BIG_PICTURE_WIDTH = 800;
  static BIG_PICTURE_HEIGHT = 400;
}