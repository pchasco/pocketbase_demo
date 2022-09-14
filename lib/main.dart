import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:pkce/pkce.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  // Run pocketbase server with --http="YOUR-NON-LOOPBACK-IP:8090" so that your android device can reach the interface
  final client = PocketBase("http://YOUR-NON-LOOPBACK-IP:8090");

  GetIt.I.registerSingleton<PocketBase>(client);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) WebView.platform = AndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
                child: const Text("Login"),
                onPressed: () async {
                  await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (BuildContext bc) {
                        return const WebviewModal();
                      });
                }),
          ],
        ),
      ),
    );
  }
}

class WebviewModal extends StatefulWidget {
  const WebviewModal({Key? key}) : super(key: key);

  @override
  State<WebviewModal> createState() => _WebviewModalState();
}

class _WebviewModalState extends State<WebviewModal> {
  final Completer<WebViewController> _controller = Completer<WebViewController>();
  PkcePair? pkcePair;

  @override
  void initState() {
    super.initState();
    pkcePair = PkcePair.generate();
  }

  @override
  Widget build(BuildContext context) {
    var redirectUri = "https://SOME-VALID-LOOKING-HOSTNAME-MATCHING-REDIRECT-URI-IN-GOOGLE-CLOUD-CONSOLE/redirect.html";
    var redirectUriEncoded = Uri.encodeQueryComponent(redirectUri);
    var clientIdEncoded = Uri.encodeQueryComponent("MY-APP-CLIENT-ID.apps.googleusercontent.com");
    return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Wrap(children: <Widget>[
          Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(25.0), topRight: Radius.circular(25.0))),
            child: SizedBox(
                height: 500,
                child: WebView(
                  gestureNavigationEnabled: false,
                  userAgent:
                      "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.5195.124 Mobile Safari/537.36",
                  initialUrl:
                      'https://accounts.google.com/o/oauth2/auth?access_type=offline&response_type=code&scope=openid&redirect_uri=$redirectUriEncoded&client_id=$clientIdEncoded',
                  javascriptMode: JavascriptMode.unrestricted,
                  navigationDelegate: (NavigationRequest request) {
                    return NavigationDecision.navigate;
                  },
                  onWebViewCreated: (WebViewController webViewController) {
                    _controller.complete(webViewController);
                  },
                  onPageFinished: (String url) async {
                    if (url.startsWith(redirectUri)) {
                      final client = GetIt.I.get<PocketBase>();
                      var uri = Uri.tryParse(url);
                      // HTTP 400 error here, produces error in PocketBase request log
                      var result = await client.users
                          .authViaOAuth2("google", uri!.queryParameters["code"]!, pkcePair!.codeVerifier, redirectUri);
                      debugPrint(result.user!.id);
                    }
                  },
                )),
          )
        ]));
  }
}
