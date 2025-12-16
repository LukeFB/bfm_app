/// ---------------------------------------------------------------------------
/// File: lib/utils/description_normalizer.dart
/// Author: Luke Fraser-Brown
///
/// Called by:
///   - Recurring transaction detection + budget analysis whenever merchants
///     need to be grouped by a clean label.
///
/// Purpose:
///   - Strip noisy reference tails from merchant descriptions so heuristics can
///     find recurring payments without splitting on random tokens.
///
/// Inputs:
///   - Raw merchant name and description strings from the transactions table.
///
/// Outputs:
///   - Lowercased, cleaned strings intended for grouping and comparisons.
///
/// Notes:
///   - Keep the cleaning rules conservative; we only remove high-confidence
///     noise so users still recognise the merchant.
/// ---------------------------------------------------------------------------

/// Helper that collapses merchant names/descriptions into stable labels.
class DescriptionNormalizer {
  /// Picks the non-empty string between `merchantName` and `description`, trims
  /// it, then runs `_normalize`. Used when we prefer merchant names but fall
  /// back to the raw description if the feed left it blank.
  static String normalizeMerchant(String? merchantName, String? description) {
    final src = (merchantName ?? '').trim().isNotEmpty
        ? merchantName!.trim()
        : (description ?? '').trim();

    return _normalize(src);
  }

  /// Direct convenience method when we only need the description cleaned.
  static String normalizeDescription(String? description) {
    return _normalize((description ?? '').trim());
  }

  /// Applies the layered cleanup:
  ///   - lowercase + collapse whitespace
  ///   - drop currency symbols + most punctuation
  ///   - remove reference/hash tokens that ruin grouping
  ///   - trim leftover tiny tails
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

  /// Heuristic to decide if a token is a one-off reference (long digits or
  /// mixed alphanumerics). Short words like "nz" or "co" are kept.
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
