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
import web_webview from '@ohos.web.webview';
import router from '@ohos.router';
import { ValueType } from '@kit.ArkData';
import { emitter } from '@kit.BasicServicesKit';

@Entry
@Component
export struct InAppBrowser {
  webviewController: web_webview.WebviewController = new web_webview.WebviewController()

  private url?: string;
  private my_header_value?: string;
  private enableJavaScript: boolean = true;
  private enableDomStorage: boolean = true;
  private flage: boolean = false;

  aboutToDisappear() {
    emitter.off("closeWebView");
  }

  aboutToAppear(){
    let params = router.getParams() as Map<string, ValueType>
    this.url = params['url'] as string;
    let options = params['options'] as Map<string, ValueType>;
    this.enableJavaScript = options['enableJavaScript'] as boolean;
    this.enableDomStorage = options['enableDomStorage'] as boolean;
    this.my_header_value=  params ['my_header_key'] as string;
    emitter.once("closeWebView", () => {
      console.info('closeWebView');
      router.back();
    });
  }
  build() {
    Row() {
      Web({ src: this.url, controller: this.webviewController })
        .javaScriptAccess(this.enableJavaScript)
        .domStorageAccess(this.enableDomStorage)
        .onRefreshAccessedHistory((event) => {
          if (event &&  !this.flage) {
            if (this.my_header_value != undefined) {
              this.webviewController.loadUrl(this.url, [{ headerKey: "my_header_key", headerValue: this.my_header_value }]);
              this.flage = true;
            } else {
              this.webviewController.loadUrl(this.url);
              this.flage = true;
            }
          }
        })

    }.width('100%').height('100%')
  }
}
