<p align="center">
  <h1 align="center"> <code>flutter_local_notifications</code> </h1>
</p>

本项目基于 [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) 开发。

## 1. 安装与使用

### 1.1 安装方式

进入到工程目录并在 pubspec.yaml 中添加以下依赖：

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

执行命令

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 使用案例

使用案例详见 [example](flutter_local_notifications/example/lib/main.dart)。

## 2. 约束与限制

### 2.1 兼容性

在以下版本中已测试通过:

1. Flutter: 3.7.12-ohos-1.1.3; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;
2. Flutter: 3.22.1-ohos-1.0.3; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;


## 3. API

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

### FlutterLocalNotificationsPlugin API 
| Name                | Description                         | Type     |  Input | Output  | ohos Support |
|---------------------|-------------------------------------|----------|--------|---------|--------------|
| initialize          | 初始化插件。                        | function | InitializationSettings initializationSettings, {DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse, DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse} | Future<bool?> | yes |
| resolvePlatformSpecificImplementation | 返回给定类型T的基础平台特定实现 | function | `<T extends FlutterLocalNotificationsPlatform>()` | T? | yes |
| getLocalTimezone    | 返回本地时区。                      | function | /      | Future<String> | yes |
| getNotificationAppLaunchDetails | 返回通知是否启动应用程序的信息 | function | / | Future<NotificationAppLaunchDetails?> | yes |
| show                | 显示带有可选有效负载的通知        | function | int id, String? title, String? body, NotificationDetails? notificationDetails, {String? payload} | Future<void> | yes |
| cancel              | 通过指定ID和可选标签取消/移除通知 | function | int id, {String? tag} | Future<void> | yes |
| cancelAll           | 取消/移除所有通知                 | function | /      | Future<void> | yes |
| zonedSchedule       | 按指定时区调度通知                | function | int id, String? title, String? body, TZDateTime scheduledDate, NotificationDetails notificationDetails, {required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation, @Deprecated bool androidAllowWhileIdle = false, AndroidScheduleMode? androidScheduleMode, String? payload, DateTimeComponents? matchDateTimeComponents} | Future<void> | yes |
| periodicallyShow    | 按指定间隔周期性显示通知          | function | int id, String? title, String? body, RepeatInterval repeatInterval, NotificationDetails notificationDetails, {String? payload, @Deprecated bool androidAllowWhileIdle = false, AndroidScheduleMode? androidScheduleMode} | Future<void> | yes |
| periodicallyShowWithDuration | 按自定义持续时间间隔显示通知 | function | int id, String? title, String? body, Duration repeatDurationInterval, NotificationDetails notificationDetails, {AndroidScheduleMode androidScheduleMode = AndroidScheduleMode.exact, String? payload} | Future<void> | no |
| pendingNotificationRequests | 返回待处理的通知请求列表     | function | / | Future<List<PendingNotificationRequest>> | yes |
| getActiveNotifications | 返回应用程序显示的活动通知列表  | function | / | Future<List<ActiveNotification>> | yes |

---

### OhosFlutterLocalNotificationsPlugin API  
| Name                | Description                         | Type     | Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|-------|---------|--------------|  
| requestNotificationsPermission | 请求通知权限 | function | / | Future<bool?> | yes |  
| areNotificationsEnabled | 检查通知是否启用 | function | / | Future<bool?> | yes |  
| addNotificationSlot | 添加通知通道槽位 | function | OhosNotificationSlot notificationSlot | Future<void> | yes |  
| deleteNotificationSlot | 删除通知通道槽位 | function | OhosNotificationSlotType slotType | Future<void> | yes |  
| getNotificationSlots | 获取通知槽位列表 | function | / | Future<List<OhosNotificationSlot>?> | yes |  

## 4. 属性

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

### OhosInitializationSettings Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| defaultIcon         | OHOS通知使用的默认图标             | String | / | String | yes |  

---

### OhosNotificationAction Filters  
| Name | Description | Type | Input | Output | ohos Support |  
|------|-------------|------|-------|--------|--------------|  
| id | 通知动作唯一标识符 | String | / | String | yes |  
| title | 通知动作显示标题 | String | / | String | yes |  
| inputs | 动作输入处理器列表 | List<OhosNotificationActionInput> | / | List<OhosNotificationActionInput> | yes |  

---

### OhosNotificationDetails Filters  
| Name | Description | Type | Input | Output | ohos Support |  
|------|-------------|------|-------|--------|--------------|  
| icon | 通知图标资源名称 | String | / | String | yes |  
| slotType | 通知渠道槽位类型 | OhosNotificationSlotType | / | OhosNotificationSlotType | yes |  
| importance | 通知优先级级别 | OhosImportance | / | OhosImportance | yes |  
| playSound | 是否播放通知声音 | bool | / | bool | yes |  
| enableVibration | 是否启用振动 | bool | / | bool | yes |  
| vibrationPattern | 自定义振动模式 | Int64List | / | Int64List | yes |  
| autoCancel | 通知是否自动取消 | bool | / | bool | yes |  
| ongoing | 是否为持续通知 | bool | / | bool | yes |  
| showProgress | 是否显示进度条 | bool | / | bool | yes |  
| maxProgress | 进度条最大值 | int | / | int | yes |  
| progress | 当前进度值 | int | / | int | yes |  
| indeterminate | 进度是否为不确定模式 | bool | / | bool | yes |  
| enableLights | 是否启用LED灯效 | bool | / | bool | yes |  
| timeoutAfter | 自动取消前持续时间 | int | / | int | yes |  
| fullScreenIntent | 是否使用全屏意图 | bool | / | bool | yes |  
| actions | 通知动作列表 | List<OhosNotificationAction> | / | List<OhosNotificationAction> | yes |  
| badgeNumber | 应用角标显示数字 | int | / | int | yes |  

---

### UILocalNotificationDateInterpretation Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| absoluteTime        | 日期被解释为绝对GMT时间            | enum | / | / | yes |  
| wallClockTime       | 日期被解释为本地时钟时间           | enum | / | / | yes |  

---

### RepeatInterval Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| everyMinute         | 每分钟间隔                          | enum     | /      | /       | yes          |  
| hourly              | 每小时间隔                          | enum     | /      | /       | yes          |  
| daily               | 每日间隔                            | enum     | /      | /       | yes          |  
| weekly              | 每周间隔                            | enum     | /      | /       | yes          |  

---

### PendingNotificationRequest Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| id                  | 通知请求ID                          | int      | /      | int     | yes          |  
| title               | 通知标题                            | String   | /      | String  | yes          |  
| body                | 通知正文内容                        | String   | /      | String  | yes          |  
| payload             | 通知负载数据                        | String   | /      | String  | yes          |  

---

### ActiveNotification Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| id                  | 通知ID                 | int      | /      | int     | yes          |  
| groupKey            | 通知分组标识                        | String   | /      | String  | yes          |  
| channelId           | 通知通道ID                          | String   | /      | String  | yes          |  
| title               | 通知显示标题                        | String   | /      | String  | yes          |  
| body                | 通知正文内容                        | String   | /      | String  | yes          |  
| payload             | 通知负载数据                        | String   | /      | String  | yes          |  
| tag                 | 通知标签标识                        | String   | /      | String  | yes          |  
| bigText             | 大文本样式显示内容                  | String   | /      | String  | yes          |  

---

### NotificationAppLaunchDetails Filters  
| Name                | Description                         | Type     |  Input | Output  | ohos Support |  
|---------------------|-------------------------------------|----------|--------|---------|--------------|  
| didNotificationLaunchApp | 是否通过通知启动应用          | bool | / | bool | yes |  
| notificationResponse | 触发通知的详细信息              | NotificationResponse | / | NotificationResponse | yes |  

---

## 5. 遗留问题

- [ ]  代理提醒 zonedSchedule 方法在 ohos 侧需要主动申请权限并通过后才能使用：[issue#15](https://gitcode.com/openharmony-sig/fluttertpc_flutter_local_notifications/issues/15)。

## 6. 其他

## 7. 开源协议

本项目基于 [The BSD-3-Clause (license)](flutter_local_notifications/LICENSE)，请自由地享受和参与开源。