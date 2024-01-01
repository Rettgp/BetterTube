import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

class WebViewContainer extends StatefulWidget {
  final String title;
  final String selectedUrl;

  const WebViewContainer(
      {super.key, required this.title, required this.selectedUrl});

  @override
  State<StatefulWidget> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  WebviewController _controller = WebviewController();
  WebviewController _minimizedController = WebviewController();
  final List<StreamSubscription> _subscriptions = [];
  final navigatorKey = GlobalKey<NavigatorState>();
  final _noCookieUrl = "www.youtube-nocookie.com";
  final _noAdsUrl = "www.yout-ube.com";
  bool _canGoBack = false;
  String _activeUrl = "";
  String _previousSearchUrl = "";
  final GlobalKey _textFieldSearch = GlobalKey();
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      initializeWebController();

      if (!mounted) return;
      setState(() {});
    } on PlatformException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text('Error'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Code: ${e.code}'),
                      Text('Message: ${e.message}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      child: Text('Continue'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                ));
      });
    }
  }

  Widget compositeView() {
    if (!_controller.value.isInitialized) {
      return const Text(
        'Not Initialized',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: Visibility(
                      visible: _canGoBack,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_backspace),
                        color: Colors.white,
                        tooltip: 'Back',
                        splashRadius: 20,
                        onPressed: () async {
                          if (isWatchingVideo()) {
                            await _controller.goBack();
                            await _controller.goBack();
                          }
                          await _controller.goBack();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    width: 400,
                    child: TextField(
                      key: _textFieldSearch,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search For...',
                        hintStyle: TextStyle(color: Colors.white),
                        contentPadding: EdgeInsets.all(15.0),
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue),
                            borderRadius:
                                BorderRadius.all(Radius.circular(30.0))),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.all(Radius.circular(30.0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Color.fromARGB(255, 61, 61, 61)),
                          borderRadius: BorderRadius.all(Radius.circular(30.0)),
                        ),
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      onSubmitted: (val) {
                        String encodedVal = Uri.encodeComponent(val);
                        _previousSearchUrl =
                            'https://www.youtube.com/results?search_query=$encodedVal';
                        _controller.loadUrl(_previousSearchUrl);
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: IconButton(
                      icon: Icon(Icons.refresh),
                      color: Colors.white,
                      splashRadius: 20,
                      onPressed: () {
                        _controller.reload();
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: IconButton(
                      icon: Icon(Icons.content_paste_go_rounded),
                      color: Colors.white,
                      tooltip: 'Play From Clipboard',
                      splashRadius: 5,
                      onPressed: () {
                        playFromClipBoard();
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Visibility(
                    visible: isWatchingVideo() && !_isMinimized,
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: IconButton(
                        icon: Icon(Icons.picture_in_picture_alt_rounded),
                        color: Colors.white,
                        tooltip: 'Minimize',
                        splashRadius: 5,
                        onPressed: () async {
                          setState(() {
                            _minimizedController = _controller;
                          });

                          initializeWebController();
                          minimize();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
                child: Card(
                    color: Colors.transparent,
                    elevation: 0,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: Stack(
                      children: [
                        Webview(
                          _controller,
                          permissionRequested: _onPermissionRequested,
                        ),
                        Positioned(
                          width: 400,
                          height: 250,
                          right: 0,
                          bottom: 0,
                          child: Visibility(
                            visible: _isMinimized,
                            child: Stack(
                              children: [
                                Webview(
                                  _minimizedController,
                                  permissionRequested: _onPermissionRequested,
                                ),
                                Align(
                                  alignment: AlignmentDirectional.topEnd,
                                  child: IconButton(
                                    icon: const Icon(Icons.close),
                                    color: Colors.white,
                                    tooltip: 'Close',
                                    splashRadius: 20,
                                    onPressed: () {
                                      setState(() {
                                        _minimizedController.dispose();
                                        _isMinimized = false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        StreamBuilder<LoadingState>(
                            stream: _controller.loadingState,
                            builder: (context, snapshot) {
                              if (snapshot.hasData &&
                                  snapshot.data == LoadingState.loading) {
                                return LinearProgressIndicator();
                              } else {
                                return SizedBox();
                              }
                            }),
                      ],
                    ))),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: compositeView(),
      ),
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  @override
  void dispose() {
    _subscriptions.forEach((s) => s.cancel());
    _controller.dispose();
    super.dispose();
  }

  Future<void> playFromClipBoard() async {
    ClipboardData? cdata = await Clipboard.getData(Clipboard.kTextPlain);
    if (cdata != null && cdata.text != null) {
      _controller.loadUrl(cdata.text!);
    }
  }

  bool isWatchingVideo() {
    return _activeUrl.contains(_noCookieUrl) ||
        _activeUrl.contains(_noAdsUrl) ||
        _activeUrl.contains("watch");
  }

  void minimize() {
    setState(() {
      _isMinimized = true;
    });
  }

  void initializeWebController() async {
    _controller = WebviewController();
    await _controller.initialize();
    _subscriptions.clear();

    _subscriptions.add(_controller.url.listen((url) {
      setState(() {
        _activeUrl = url;
      });
      print(url);
      if (!url.contains("?")) {
        return;
      }
      if (url.contains("watch") &&
          !url.contains(_noCookieUrl) &&
          !url.contains(_noAdsUrl)) {
        _controller
            .loadUrl(url.replaceAll("www.youtube.com", "www.yout-ube.com"));
      }
    }));

    _subscriptions
        .add(_controller.containsFullScreenElementChanged.listen((flag) {
      debugPrint('Contains fullscreen element: $flag');
      windowManager.setFullScreen(flag);
    }));

    _subscriptions.add(_controller.loadingState.listen((event) {
      if (event == LoadingState.navigationCompleted) {
        _controller.executeScript(
            'window.document.getElementById("center").innerHTML = ""');
        _controller.executeScript(
            'var value = {"has_error": window.document.getElementsByClassName("ytp-error").length}; window.chrome.webview.postMessage(value)');
        File('lib/resolution.js').readAsString().then((String contents) {
          print("Load resolution.js");
          _controller.executeScript(contents);
        });
      }
    }));

    _subscriptions.add(_controller.webMessage.listen((event) {
      if (event["has_error"] == 1) {
        _controller.reload();
      }
    }));

    _subscriptions.add(_controller.historyChanged.listen((history) {
      setState(() {
        _canGoBack = history.canGoBack;
      });
    }));

    await _controller.setBackgroundColor(Colors.transparent);
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.allow);
    if (!_previousSearchUrl.isEmpty) {
      await _controller.loadUrl(_previousSearchUrl);
    } else {
      await _controller.loadUrl("https://www.youtube.com");
    }
  }
}
