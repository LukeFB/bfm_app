/// ---------------------------------------------------------------------------
/// File: lib/utils/app_route_observer.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `lib/app.dart` when wiring `MaterialApp.navigatorObservers`.
///
/// Purpose:
///   - Exposes a singleton `RouteObserver` so screens can subscribe and refresh
///     when a user navigates back to them.
///
/// Inputs:
///   - Hooks into Flutter's navigator stack; no external dependencies.
///
/// Outputs:
///   - Emits `RouteAware` callbacks for listeners that register.
/// ---------------------------------------------------------------------------
import 'package:flutter/widgets.dart';

/// Shared observer instance used across screens to track route pushes/pops. Any
/// widget can add itself as `RouteAware` to get lifecycle events on focus.
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();

