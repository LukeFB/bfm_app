import 'dart:collection';

/// In-memory ring buffer of debug log entries, viewable from the settings screen.
/// Captures API request timings, sync events, and other diagnostics.
class DebugLog {
  DebugLog._();
  static final DebugLog instance = DebugLog._();

  static const int _maxEntries = 200;
  final _entries = Queue<DebugEntry>();

  List<DebugEntry> get entries => _entries.toList();

  void add(String tag, String message) {
    _entries.addLast(DebugEntry(
      time: DateTime.now(),
      tag: tag,
      message: message,
    ));
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
  }

  /// Shorthand for API request logs.
  void api(String method, String path, int? status, int ms) {
    add('API', '$method $path → ${status ?? 'timeout'} (${ms}ms)');
  }

  void clear() => _entries.clear();
}

class DebugEntry {
  final DateTime time;
  final String tag;
  final String message;

  const DebugEntry({
    required this.time,
    required this.tag,
    required this.message,
  });

  String get formatted {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s [$tag] $message';
  }
}
