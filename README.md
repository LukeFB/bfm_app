# bfm_app
Frontend for BFM financial assistance app

# Instructions
Follow 
https://www.geeksforgeeks.org/installation-guide/how-to-install-flutter-on-windows/
https://codelabs.developers.google.com/codelabs/flutter-codelab-first#0

# To run
start pixel 5 VM on android studio
Run:
flutter clean,
flutter pub get,
flutter run -d emulator-5554.

# Errors
If getting "Error initializing DevFS: DevFSException(Service disconnected, _createDevFS: (112) Service has disappeared, null)"
Stop VM
Run:
adb kill-server,
adb start-server.

Restart app


