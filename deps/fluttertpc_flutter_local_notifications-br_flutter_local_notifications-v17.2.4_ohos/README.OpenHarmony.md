<p align="center">
  <h1 align="center"> <code>flutter_local_notifications</code> </h1>
</p>

This project is based on [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications).

## 1. Installation and Usage

### 1.1 Installation

Go to the project directory and add the following dependencies in pubspec.yaml

<!-- tabs:start -->

#### pubspec.yaml

```yaml
...

dependencies:
  flutter_local_notifications:
    git:
      url: https://gitcode.com/openharmony-sig/fluttertpc_flutter_local_notifications.git
      path: flutter_local_notifications
      ref: br_flutter_local_notifications-v17.2.4_ohos  
...
```

Execute Command

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 Usage

For use cases [example](flutter_local_notifications/example/lib/main.dart).

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

1. Flutter: 3.7.12-ohos-1.1.3; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;
2. Flutter: 3.22.1-ohos-1.0.3; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;


## 3. API

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

### FlutterLocalNotificationsPlugin API 
| Name                | Description                         | Type     |  Input | Output  | ohos Support |
|---------------------|-------------------------------------|----------|--------|---------|--------------|
| initialize          | Initializes the plugin.             | function | InitializationSettings initializationSettings, {DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse, DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse} | Future<bool?> | yes |
| resolvePlatformSpecificImplementation | Returns the underlying platform-specific implementation of given type T | function | <T extends FlutterLocalNotificationsPlatform>() | T? | yes |
| getLocalTimezone    | Returns the local timezone.         | function | /      | Future<String> | yes |
| getNotificationAppLaunchDetails | Returns info on if a notification launched the application. | function | / | Future<NotificationAppLaunchDetails?> | yes |
| show                | Show a notification with payload.   | function | int id, String? title, String? body, NotificationDetails? notificationDetails, {String? payload} | Future<void> | yes |
| cancel              | Cancel/remove the notification by id and optional tag. | function | int id, {String? tag} | Future<void> | yes |
| cancelAll           | Cancels/removes all notifications.  | function | /      | Future<void> | yes |
| zonedSchedule       | Schedules a notification with timezone. | function | int id, String? title, String? body, TZDateTime scheduledDate, NotificationDetails notificationDetails, {required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation, @Deprecated bool androidAllowWhileIdle = false, AndroidScheduleMode? androidScheduleMode, String? payload, DateTimeComponents? matchDateTimeComponents} | Future<void> | yes |
| periodicallyShow    | Periodically show notification.     | function | int id, String? title, String? body, RepeatInterval repeatInterval, NotificationDetails notificationDetails, {String? payload, @Deprecated bool androidAllowWhileIdle = false, AndroidScheduleMode? androidScheduleMode} | Future<void> | yes |
| periodicallyShowWithDuration | Shows notifications at custom duration intervals | function | int id, String? title, String? body, Duration repeatDurationInterval, NotificationDetails notificationDetails, {AndroidScheduleMode androidScheduleMode = AndroidScheduleMode.exact, String? payload} | Future<void> | no |  
| pendingNotificationRequests | Returns list of pending notifications. | function | / | Future<List<PendingNotificationRequest>> | yes |
| getActiveNotifications | Returns list of active notifications. | function | / | Future<List<ActiveNotification>> | yes |

---

### OhosFlutterLocalNotificationsPlugin API  
| Name                | Description                         | Type     | Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|-------|---------|--------------|  
| requestNotificationsPermission | Requests notification permissions | function | / | Future<bool?> | yes |  
| areNotificationsEnabled | Checks if notifications are enabled | function | / | Future<bool?> | yes |  
| addNotificationSlot | Adds a notification channel slot | function | OhosNotificationSlot notificationSlot | Future<void> | yes |  
| deleteNotificationSlot | Removes a notification channel slot | function | OhosNotificationSlotType slotType | Future<void> | yes |  
| getNotificationSlots | Gets list of notification slots | function | / | Future<List<OhosNotificationSlot>?> | yes |  

## 4. Properties

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

### OhosInitializationSettings Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| defaultIcon         | The default icon used for notifications on OHOS | String | / | String | yes |  

---

### OhosNotificationAction Filters  
| Name | Description | Type | Input | Output | ohos Support |  
|------|-------------|------|-------|--------|--------------|  
| id | Unique identifier for the notification action | String | / | String | yes |  
| title | Display title for the notification action | String | / | String | yes |  
| inputs | List of input handlers for the action | List<OhosNotificationActionInput> | / | List<OhosNotificationActionInput> | yes |  

---

### OhosNotificationDetails Filters  
| Name | Description | Type | Input | Output | ohos Support |  
|------|-------------|------|-------|--------|--------------|  
| icon | Resource name of the notification icon | String | / | String | yes |  
| slotType | Type of notification channel slot | OhosNotificationSlotType | / | OhosNotificationSlotType | yes |  
| importance | Priority level of the notification | OhosImportance | / | OhosImportance | yes |  
| playSound | Whether to play sound for the notification | bool | / | bool | yes |  
| enableVibration | Whether to enable vibration | bool | / | bool | yes |  
| vibrationPattern | Custom vibration pattern | Int64List | / | Int64List | yes |  
| autoCancel | Whether the notification auto-cancels | bool | / | bool | yes |  
| ongoing | Whether the notification is ongoing | bool | / | bool | yes |  
| showProgress | Whether to show progress bar | bool | / | bool | yes |  
| maxProgress | Maximum progress value | int | / | int | yes |  
| progress | Current progress value | int | / | int | yes |  
| indeterminate | Whether progress is indeterminate | bool | / | bool | yes |  
| enableLights | Whether to enable LED lights | bool | / | bool | yes |  
| timeoutAfter | Duration before auto-canceling | int | / | int | yes |  
| fullScreenIntent | Whether to use full-screen intent | bool | / | bool | yes |  
| actions | List of notification actions | List<OhosNotificationAction> | / | List<OhosNotificationAction> | yes |  
| badgeNumber | Number to display on app badge | int | / | int | yes |  

---

### UILocalNotificationDateInterpretation Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| absoluteTime        | The date is interpreted as absolute GMT time | enum | / | / | yes |  
| wallClockTime       | The date is interpreted as a wall-clock time | enum | / | / | yes |  

---

### RepeatInterval Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| everyMinute         | An interval for every minute        | enum     | /      | /       | yes          |  
| hourly              | Hourly interval                     | enum     | /      | /       | yes          |  
| daily               | Daily interval                      | enum     | /      | /       | yes          |  
| weekly              | Weekly interval                     | enum     | /      | /       | yes          |  

---

### PendingNotificationRequest Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| id                  | The notification's id               | int      | /      | int     | yes          |  
| title               | The notification's title            | String   | /      | String  | yes          |  
| body                | The notification's body             | String   | /      | String  | yes          |  
| payload             | The notification's payload          | String   | /      | String  | yes          |  

---

### ActiveNotification Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| id                  | The notification's id (nullable)    | int      | /      | int     | yes          |  
| groupKey            | The notification's group key        | String   | /      | String  | yes          |  
| channelId           | The notification's channel ID       | String   | /      | String  | yes          |  
| title               | The notification's title            | String   | /      | String  | yes          |  
| body                | The notification's body             | String   | /      | String  | yes          |  
| payload             | The notification's payload          | String   | /      | String  | yes          |  
| tag                 | The notification's tag              | String   | /      | String  | yes          |  
| bigText             | Longer text in big text style       | String   | /      | String  | yes          |  

---

### NotificationAppLaunchDetails Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|   
| didNotificationLaunchApp | Indicates if app was launched via notification | bool | / | bool | yes |  
| notificationResponse | Details of the triggering notification | NotificationResponse | / | NotificationResponse | yes |  

---
  
## 5. Known Issues

- [ ]  On ohos, the zonedSchedule method for scheduled reminders requires explicit permission grants and cannot be utilized until authorized:[issue#15](https://gitcode.com/openharmony-sig/fluttertpc_flutter_local_notifications/issues/15).

## 6. Others

## 7. License

This project is licensed under [The BSD-3-Clause (license)](flutter_local_notifications/LICENSE).