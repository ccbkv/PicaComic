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

import { image } from '@kit.ImageKit';
import { notificationManager } from '@kit.NotificationKit';

interface NotificationContentUtilResultType {
  notificationContentType: notificationManager.ContentType
  normal?: notificationManager.NotificationBasicContent
  longText?: notificationManager.NotificationLongTextContent
  multiLine?: notificationManager.NotificationMultiLineContent
  picture?: notificationManager.NotificationPictureContent
  liveView?: notificationManager.NotificationSystemLiveViewContent
}

class NotificationContentUtil {
  initBasicNotificationContent(title: string, body: string, subText?: string) {
    if (!title || !body) {
      return null;
    }
    let basicContent: notificationManager.NotificationBasicContent = {
      title: title,
      text: body,
      additionalText: subText ?? ""
    }
    let result: NotificationContentUtilResultType = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: basicContent
    }
    return result;
  }

  initNotificationLongTextContent(title: string, body: string, notificationBriefText: string, notificationExpandedTitle: string, notificationLongText: string, subText?: string) {
    if (!title || !body || !notificationLongText || !notificationBriefText || !notificationExpandedTitle) {
      return null;
    }
    let result: NotificationContentUtilResultType = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_LONG_TEXT,
      longText: {
        title: title,
        text: body,
        additionalText: subText ?? "",
        expandedTitle: notificationExpandedTitle,
        longText: notificationLongText,
        briefText: notificationBriefText
      }
    };
    return result;
  }

  initNotificationMultiLineContent(title: string, body: string, notificationLongTitle: string, notificationBriefText: string, notificationLines: Array<string>, subText?: string) {
    if (!title || !body || !notificationLongTitle || !notificationBriefText || !notificationLines) {
      return null;
    }
    let result: NotificationContentUtilResultType = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_MULTILINE, // 通知内容类型
      multiLine: {
        title: title,
        text: body,
        additionalText: subText ?? '',
        longTitle: notificationLongTitle,
        briefText: notificationBriefText,
        lines: notificationLines
      }
    };
    return result;
  }

  initNotificationPictureContent(title: string, body: string, notificationExpandedTitle: string, notificationBriefText: string, notificationPicture: image.PixelMap, subText?: string) {
    if (!title || !body || !notificationExpandedTitle || !notificationBriefText || !notificationPicture) {
      return null;
    }
    let notificationPictureContent: notificationManager.NotificationPictureContent = {
      title: title,
      text: body,
      additionalText: subText ?? '',
      briefText: notificationBriefText,
      expandedTitle: notificationExpandedTitle,
      picture: notificationPicture
    };
    let result: NotificationContentUtilResultType = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_PICTURE, // 通知内容类型
      picture: notificationPictureContent
    };
    return result;
  }

  initNotificationSystemLiveViewContent(title: string, text: string, typeCode: number, initialTime?: number,
    isCountDown?: boolean, isPaused?: boolean, isInTitle?: boolean) {
    if (!title || !text || !typeCode) {
      return null;
    }
    let notificationSystemLiveViewContent: notificationManager.NotificationSystemLiveViewContent = {
      typeCode: typeCode,
      title: title,
      text: text,
      time: {
        initialTime: initialTime,
        isCountDown: isCountDown,
        isPaused: isPaused,
        isInTitle: isInTitle,
      }
    }
    let result: NotificationContentUtilResultType = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
      liveView: notificationSystemLiveViewContent
    }
    return result;
  }
}

export let notificationContentUtil = new NotificationContentUtil();