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

import 'package:flutter_local_notifications/src/platform_specifics/ohos/styles/live_view_style_information.dart';

import '../../../flutter_local_notifications.dart';

extension OhosInitializationSettingsMapper on OhosInitializationSettings {
  Map<String, Object> toMap() => <String, Object>{'defaultIcon': defaultIcon};
}

extension OhosDefaultStyleInformationMapper on OhosDefaultStyleInformation {
  Map<String, Object?> toMap() => _convertDefaultStyleInformationToMap(this);
}

Map<String, Object?> _convertDefaultStyleInformationToMap(
        OhosDefaultStyleInformation styleInformation) =>
    <String, Object?>{
      'htmlFormatContent': styleInformation.htmlFormatContent,
      'htmlFormatTitle': styleInformation.htmlFormatTitle
    };

extension OhosBigTexStyleInformationMapper on OhosBigTextStyleInformation {
  Map<String, Object?> toMap() => _convertDefaultStyleInformationToMap(this)
    ..addAll(<String, Object?>{
      'bigText': bigText,
      'htmlFormatBigText': htmlFormatBigText,
      'contentTitle': contentTitle,
      'htmlFormatContentTitle': htmlFormatContentTitle,
      'summaryText': summaryText,
      'htmlFormatSummaryText': htmlFormatSummaryText
    });
}

extension OhosInboxStyleInformationMapper on OhosInboxStyleInformation {
  Map<String, Object?> toMap() => _convertDefaultStyleInformationToMap(this)
    ..addAll(<String, Object?>{
      'contentTitle': contentTitle,
      'htmlFormatContentTitle': htmlFormatContentTitle,
      'summaryText': summaryText,
      'htmlFormatSummaryText': htmlFormatSummaryText,
      'lines': lines,
      'htmlFormatLines': htmlFormatLines
    });
}

extension OhosLiveViewStyleInformationMapper on OhosLiveViewStyleInformation {
  Map<String, Object?> toMap() => _convertDefaultStyleInformationToMap(this)
      ..addAll(<String, Object?>{
        'title': title,
        'text': text,
        'typeCode': typeCode,
        'initialTime': initialTime,
        'isCountDown': isCountDown,
        'isPaused': isPaused,
        'isInTitle': isInTitle
      });
}

extension BigPictureStyleInformationMapper on OhosBigPictureStyleInformation {
  Map<String, Object?> toMap() => _convertDefaultStyleInformationToMap(this)
    ..addAll(_convertBigPictureToMap())
    ..addAll(<String, Object?>{
      'contentTitle': contentTitle,
      'summaryText': summaryText,
      'htmlFormatContentTitle': htmlFormatContentTitle,
      'htmlFormatSummaryText': htmlFormatSummaryText
    });

  Map<String, Object> _convertBigPictureToMap() => <String, Object>{
    'bigPicture': bigPicture.data,
    'bigPictureBitmapSource': bigPicture.source.index,
  };
}

extension OhosNotificationSlotMapper on OhosNotificationSlot {
  Map<String, Object?> toMap() => <String, Object?>{
    'slotType': slotType.index,
    'description': description,
    'importance': importance.value,
    'playSound': playSound,
    'enableVibration': enableVibration,
    'vibrationPattern': vibrationPattern,
    'showBadge': showBadge,
    'enableLights': enableLights,
    'ledColorAlpha': ledColor?.alpha,
    'ledColorRed': ledColor?.red,
    'ledColorGreen': ledColor?.green,
    'ledColorBlue': ledColor?.blue,
    'lockscreenVisibility': lockscreenVisibility,
    'bypassDnd': bypassDnd,
    'slotAction':
    OhosNotificationSlotAction.createIfNotExists.index
  }..addAll(_convertNotificationSoundToMap(sound));
}

Map<String, Object> _convertNotificationSoundToMap(
    OhosNotificationSound? sound) {
  if (sound is RawResourceOhosNotificationSound) {
    return <String, Object>{
      'sound': sound!.sound,
      'soundSource': OhosNotificationSoundSource.rawResource.index,
    };
  } else if (sound is UriOhosNotificationSound) {
    return <String, Object>{
      'sound': sound!.sound,
      'soundSource': OhosNotificationSoundSource.uri.index,
    };
  } else {
    return <String, Object>{};
  }
}

extension OhosNotificationDetailsMapper on OhosNotificationDetails {
  Map<String, Object?> toMap() => <String, Object?>{
        'slotType': slotType.value,
        'slotDesc': slotDesc,
        'icon': icon,
        'importance': importance.value,
        'playSound': playSound,
        'enableVibration': enableVibration,
        'enableLights': enableLights,
        'vibrationPattern': vibrationPattern,
        'groupKey': groupKey,
        'autoCancel': autoCancel,
        'ongoing': ongoing,
        'silent': silent,
        'colorAlpha': color?.alpha,
        'colorRed': color?.red,
        'colorGreen': color?.green,
        'colorBlue': color?.blue,
        'onlyAlertOnce': onlyAlertOnce,
        'showWhen': showWhen,
        'when': when,
        'usesChronometer': usesChronometer,
        'chronometerCountDown': chronometerCountDown,
        'slotShowBadge': slotShowBadge,
        'showProgress': showProgress,
        'maxProgress': maxProgress,
        'progress': progress,
        'indeterminate': indeterminate,
        'ledColorAlpha': color?.alpha,
        'ledColorRed': color?.red,
        'ledColorGreen': color?.green,
        'ledColorBlue': color?.blue,
        'slotAction': slotAction.index,
        'timeoutAfter': timeoutAfter,
        'fullScreenIntent': fullScreenIntent,
        'subText': subText,
        'tag': tag,
        'colorized': colorized,
        'badgeNumber': badgeNumber,
        'lockscreenVisibility': lockscreenVisibility,
        'bypassDnd': bypassDnd,
        'isFloatingIcon': isFloatingIcon
      }
        ..addAll(_convertActionsToMap(actions))
        ..addAll(_convertStyleInformationToMap())
        ..addAll(_convertNotificationSoundToMap(sound))
        ..addAll(_convertLargeIconToMap());

  Map<String, Object> _convertLargeIconToMap() {
    if (largeIcon == null) {
      return <String, Object>{};
    }
    return <String, Object>{
      'largeIcon': largeIcon!.data,
      'largeIconBitmapSource': largeIcon!.source.index,
    };
  }

  Map<String, Object?> _convertStyleInformationToMap() {
    print('_convertStyleInformationToMap styleInformation = $styleInformation');
    if (styleInformation is OhosBigTextStyleInformation) {
      return <String, Object?>{
        'style': OhosNotificationStyle.bigText.index,
        'styleInformation':
            (styleInformation as OhosBigTextStyleInformation?)?.toMap(),
      };
    } else if (styleInformation is OhosInboxStyleInformation) {
      return <String, Object?>{
        'style': OhosNotificationStyle.inbox.index,
        'styleInformation':
            (styleInformation as OhosInboxStyleInformation?)?.toMap(),
      };
    } else if (styleInformation is OhosBigPictureStyleInformation) {
      return <String, Object?>{
        'style': OhosNotificationStyle.bigPicture.index,
        'styleInformation':
        (styleInformation as OhosBigPictureStyleInformation?)?.toMap(),
      };
    } else if (styleInformation is OhosLiveViewStyleInformation) {
      print('1111111111111');
      return <String, Object?>{
        'style': OhosNotificationStyle.liveView.index,
        'styleInformation':
        (styleInformation as OhosLiveViewStyleInformation?)?.toMap(),
      };
    } else if (styleInformation is OhosDefaultStyleInformation) {
      return <String, Object?>{
        'style': OhosNotificationStyle.defaultStyle.index,
        'styleInformation':
            (styleInformation as OhosDefaultStyleInformation?)?.toMap(),
      };
    } else {
      return <String, Object>{
        'style': OhosNotificationStyle.defaultStyle.index,
        'styleInformation': const OhosDefaultStyleInformation(false, false).toMap(),
      };
    }
  }

  Map<String, Object> _convertActionsToMap(
      List<OhosNotificationAction>? actions) {
    if (actions == null) {
      return <String, Object>{};
    }
    return <String, Object>{
      'actions': actions
          .map(
            (OhosNotificationAction e) => <String, dynamic>{
              'id': e.id,
              'title': e.title,
              'inputs': e.inputs
                  .map((OhosNotificationActionInput input) =>
                      _convertInputToMap(input))
                  .toList()
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> _convertInputToMap(
      OhosNotificationActionInput input) =>
      <String, dynamic>{
      };
}
