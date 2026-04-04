import 'dart:io' as io;

import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/network/nhentai_network/nhentai_main_network.dart';
import 'package:pica_comic/pages/webview.dart';
import 'package:pica_comic/utils/translations.dart';


void nhLogin(void Function() onFinished) async{

    if(App.isLinux) {
    var webview = DesktopWebview(
      initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
      onTitleChange: (title, controller) async{
        print(title);
        if(title == "nhentai.net")  return;
        if (!title.contains("Login") && !title.contains("Register") && title.contains("nhentai")) {
          var ua = controller.userAgent;
          if(ua != null){
            appdata.implicitData[3] = ua;
            appdata.writeImplicitData();
          }
          var cookies = await controller.getCookies("${NhentaiNetwork().baseUrl}/");
          List<io.Cookie> cookiesList = [];
          if (cookies != null) {
            cookies.forEach((key, value) {
              var cookie = io.Cookie(key, value);
              if(key == 'access_token') {
                NhentaiNetwork().logged = true;
              }
              cookie.domain = ".nhentai.net";
              if (key != "cf_clearance") {
                cookiesList.add(cookie);
              }
            });
          }
          NhentaiNetwork().cookieJar!.saveFromResponse(
            Uri.parse(NhentaiNetwork().baseUrl), cookiesList);
          if (!NhentaiNetwork().logged) {
            showToast(message: 'Login failed: access token cookie missing');
            return;
          }
          onFinished();
          controller.close();
        }
      },
    );
    webview.open();
  } else {
    await App.globalTo(() => AppWebview(
        initialUrl: "${NhentaiNetwork().baseUrl}/login/?next=/",
        singlePage: true,
        onTitleChange: (title, controller) async{
          if (!title.contains("Login") && !title.contains("Register") && title.contains("nhentai")) {
            var ua = await controller.getUA();
            if(ua != null){
              appdata.implicitData[3] = ua;
              appdata.writeImplicitData();
            }
            var cookiesList = await controller.getCookies("${NhentaiNetwork().baseUrl}/");
            if (cookiesList != null) {
              for (var cookie in cookiesList) {
                if(cookie.name == 'access_token'){
                NhentaiNetwork().logged = true;
              }
                cookie.domain = ".nhentai.net";
              }
              NhentaiNetwork().cookieJar!.saveFromResponse(
                Uri.parse(NhentaiNetwork().baseUrl), cookiesList);
            }
            if (!NhentaiNetwork().logged) {
              showToast(message: 'Login failed: access token cookie missing');
              return;
            }
            onFinished();
            App.globalBack();
          }
        },
      ));
  }
}
