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

import { LocalNotificationsConstants } from '../LocalNotificationsConstants';

export class NotificationAction {
  id?: string;
  title: string;
  actionInputs?: Array<NotificationActionInput>;

  constructor(map: Map<string, object>) {
    let idValue = map.get(LocalNotificationsConstants.ID);
    this.id = idValue ? String(idValue) : undefined;
    let titleValue = map.get(LocalNotificationsConstants.TITLE)
    this.title = titleValue ? String(titleValue) : "";
    let inputs: Array<Map<string, object>> | undefined = map.get(LocalNotificationsConstants.INPUTS) as (Array<Map<string, object>> | undefined);
    if (inputs && inputs.length > 0) {
      this.actionInputs = [];
      for (let item of inputs) {
        item && this.actionInputs.push(new NotificationActionInput());
      }
    }
  }
}

export class NotificationActionInput {
}