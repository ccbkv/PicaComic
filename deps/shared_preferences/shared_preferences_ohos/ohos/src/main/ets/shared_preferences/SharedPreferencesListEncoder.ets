/*
 * Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
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
/**
 * An interface used to provide conversion logic between Array<string> and string for
 * SharedPreferencesPlugin.
 */
export interface SharedPreferencesListEncoder {
  /** Converts list to String for storing in shared preferences. */
  encode(list: Array<string>): string;
  /** Converts stored String representing List<String> to List. */
  decode(listString: string): ESObject;
}