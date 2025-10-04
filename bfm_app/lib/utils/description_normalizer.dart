// File: description_normalizer.dart
// Author: Luke Fraser-Brown
//
// Centralized description/merchant cleanup used by recurring + habit detectors.
//
// The goal here is to reduce noisy reference tails (e.g., "CITYFITNESSG 10100B830076")
// while preserving meaningful merchant tokens. We try to keep human-readable words
// and remove one-off hash-like fragments that would break grouping.

class DescriptionNormalizer {
  static String normalizeMerchant(String? merchantName, String? description) {
    final src = (merchantName ?? '').trim().isNotEmpty
        ? merchantName!.trim()
        : (description ?? '').trim();

    return _normalize(src);
  }

  static String normalizeDescription(String? description) {
    return _normalize((description ?? '').trim());
  }

  static String _normalize(String s) {
    // Lowercase, collapse whitespace.
    var out = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove currency symbols and most punctuation we know are noise for grouping.
    out = out.replaceAll(RegExp(r'[£$€¥]'), '');
    out = out.replaceAll(RegExp(r'[^\w\s&\.-]'), ' '); // keep word chars, space, &, ., -

    // Remove long purely alphanumeric tokens that look like refs (e.g., 10100B830076).
    // We consider "hash-like" as 6+ mixed chars or 8+ digits.
    out = out
        .split(' ')
        .where((t) => !_looksLikeReferenceToken(t))
        .join(' ')
        .trim();

    // Trim any trailing tiny tokens left behind that are likely noise (1–2 chars).
    out = out.replaceAll(RegExp(r'\b[a-z0-9]{1,2}$'), '').trim();

    // Collapse again after removals.
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();

    return out;
  }

  static bool _looksLikeReferenceToken(String t) {
    if (t.isEmpty) return false;
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(t);
    final hasDigits = RegExp(r'\d').hasMatch(t);
    // Very long numbers or mixed refs are almost always one-off.
    if (t.length >= 8 && RegExp(r'^\d+$').hasMatch(t)) return true; // all digits 8+
    if (t.length >= 6 && hasLetters && hasDigits) return true; // mixed 6+
    // Typical POS tails like "nz", "ltd", "co" we keep (short words).
    if (t.length <= 2) return false;
    return false;
  }
}
