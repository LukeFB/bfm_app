/// ---------------------------------------------------------------------------
/// File: lib/theme/colors.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - `lib/app.dart` theme setup plus any widget needing shared colors.
///
/// Purpose:
///   - Centralises bespoke color tokens so screens/widgets stay consistent.
///
/// Inputs:
///   - None; constants defined here are consumed elsewhere.
///
/// Outputs:
///   - `Color` instances the UI can reference directly.
///
/// Notes:
///   - Expand this file when we lock in a full design system; keeping the
///     palette here avoids magic numbers in widgets.
/// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';

/// Base beige background used across dashboard cards and empty states.
const bfmBeige = Color(0xFFF7F2E8);


// TODO: link and add themes