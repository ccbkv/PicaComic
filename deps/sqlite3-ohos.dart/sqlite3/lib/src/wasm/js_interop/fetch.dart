@JS()
library;

import 'dart:js_interop';

import 'package:web/web.dart' show URL, Response, RequestInit;

@JS()
external JSPromise<Response> fetch(URL resource, [RequestInit? options]);
