import 'dart:async';

import '../../version.dart';

final skipCreatedWithSentinel = Object();

String createdWith() => Zone.current[skipCreatedWithSentinel] == true
    ? ''
    : '# Created with package:mono_repo v$packageVersion\n';
