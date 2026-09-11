/// Turns a node's `region` string into something a person recognises.
///
/// The backend's convention is `<iso2>-<city>` — `in-mumbai`, `de-frankfurt`
/// (see `SEED_NODE_REGION` in `backend/prisma/seed.ts`). That is enough to
/// derive a country name and a flag without the API growing a geo field, and
/// the flag comes from the country code arithmetically rather than from an
/// asset bundle.
///
/// Nothing here is load-bearing: a region the parser does not understand still
/// renders, just as its raw string under a globe. That matters because an
/// operator can seed any region value they like — an AWS-style `ap-south-1`
/// parses no country, and must not be shown a garbage two-letter flag.
class RegionGeo {
  const RegionGeo({required this.raw, this.countryCode, this.city});

  /// The region exactly as the API returned it.
  final String raw;

  /// Upper-case ISO 3166-1 alpha-2, or null when the prefix is not a country
  /// this app recognises.
  final String? countryCode;

  /// Title-cased city, or null when the region carried no city segment.
  final String? city;

  static RegionGeo parse(String region) {
    final trimmed = region.trim();
    final dash = trimmed.indexOf('-');
    if (dash != 2) return RegionGeo(raw: trimmed);

    final code = trimmed.substring(0, 2).toUpperCase();
    // Only treat the prefix as a country when it is one we can name. An
    // unrecognised code would otherwise produce a flag of two blank letters.
    if (!_countries.containsKey(code)) return RegionGeo(raw: trimmed);

    final rest = trimmed.substring(dash + 1);
    return RegionGeo(
      raw: trimmed,
      countryCode: code,
      city: rest.isEmpty ? null : _titleCase(rest),
    );
  }

  /// The name to headline a location with. Falls back to the raw region so an
  /// unparsed value is still identifiable rather than blank.
  String get countryName => _countries[countryCode] ?? raw;

  /// Regional-indicator pair, or null when there is no country to draw.
  ///
  /// Built from the code rather than looked up: each letter maps to the
  /// regional indicator symbol at U+1F1E6 + its offset from 'A', and a pair of
  /// them is what the platform renders as a flag.
  String? get flag {
    final code = countryCode;
    if (code == null) return null;
    const base = 0x1F1E6;
    const letterA = 0x41;
    return String.fromCharCodes([
      base + (code.codeUnitAt(0) - letterA),
      base + (code.codeUnitAt(1) - letterA),
    ]);
  }

  /// Sort key for a location list. Named countries first and alphabetical,
  /// then the unparsed regions, so a misconfigured node lands at the bottom
  /// instead of scattered through the list.
  String get sortKey => countryCode == null ? '￿$raw' : countryName;

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'[-_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Deliberately not the full ISO list. These are the countries a small VPN
  /// fleet plausibly sits in; anything else falls through to the raw region,
  /// which is the honest rendering for a code we cannot name.
  static const _countries = <String, String>{
    'AE': 'United Arab Emirates',
    'AR': 'Argentina',
    'AT': 'Austria',
    'AU': 'Australia',
    'BE': 'Belgium',
    'BG': 'Bulgaria',
    'BR': 'Brazil',
    'CA': 'Canada',
    'CH': 'Switzerland',
    'CL': 'Chile',
    'CZ': 'Czechia',
    'DE': 'Germany',
    'DK': 'Denmark',
    'EE': 'Estonia',
    'ES': 'Spain',
    'FI': 'Finland',
    'FR': 'France',
    'GB': 'United Kingdom',
    'GR': 'Greece',
    'HK': 'Hong Kong',
    'HU': 'Hungary',
    'ID': 'Indonesia',
    'IE': 'Ireland',
    'IL': 'Israel',
    'IN': 'India',
    'IS': 'Iceland',
    'IT': 'Italy',
    'JP': 'Japan',
    'KR': 'South Korea',
    'LT': 'Lithuania',
    'LU': 'Luxembourg',
    'LV': 'Latvia',
    'MX': 'Mexico',
    'MY': 'Malaysia',
    'NL': 'Netherlands',
    'NO': 'Norway',
    'NZ': 'New Zealand',
    'PH': 'Philippines',
    'PL': 'Poland',
    'PT': 'Portugal',
    'RO': 'Romania',
    'RS': 'Serbia',
    'SA': 'Saudi Arabia',
    'SE': 'Sweden',
    'SG': 'Singapore',
    'SK': 'Slovakia',
    'TH': 'Thailand',
    'TR': 'Turkey',
    'TW': 'Taiwan',
    'UA': 'Ukraine',
    'US': 'United States',
    'VN': 'Vietnam',
    'ZA': 'South Africa',
  };
}
