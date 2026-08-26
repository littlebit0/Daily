import 'package:flutter/foundation.dart';

const bool isWindowsTestEdition = kDebugMode || kProfileMode;

bool isWindowsTestEditionForMode({
  required bool isDebugMode,
  required bool isProfileMode,
}) {
  return isDebugMode || isProfileMode;
}
