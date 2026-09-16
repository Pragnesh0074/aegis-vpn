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
  String get countryName => _countries[countryCode]?.name ?? raw;

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

  /// Rough east-west position of this country, in degrees, or null when the
  /// region named no country we know.
  ///
  /// A country centroid, not the node's city: the United States is one number
  /// here and a node in Oregon reads the same as one in Virginia. That is the
  /// resolution this is used at — see `NodeRanking`, which buckets nodes into
  /// bands an hour of longitude wide before it prefers one over another — and a
  /// city table would be a second thing to keep in step with the fleet for no
  /// change in the answer.
  double? get longitude => countryCode == null ? null : _countries[countryCode]?.longitude;

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
  ///
  /// The longitude is a country centroid, carried here because it is the one
  /// coordinate the app can compare a device against without asking for a
  /// location permission — see [longitude].
  static const _countries = <String, ({String name, double longitude})>{
    'AE': (name: 'United Arab Emirates', longitude: 54.0),
    'AR': (name: 'Argentina', longitude: -64.0),
    'AT': (name: 'Austria', longitude: 14.5),
    'AU': (name: 'Australia', longitude: 134.0),
    'BE': (name: 'Belgium', longitude: 4.5),
    'BG': (name: 'Bulgaria', longitude: 25.5),
    'BR': (name: 'Brazil', longitude: -51.0),
    'CA': (name: 'Canada', longitude: -106.0),
    'CH': (name: 'Switzerland', longitude: 8.2),
    'CL': (name: 'Chile', longitude: -71.0),
    'CZ': (name: 'Czechia', longitude: 15.5),
    'DE': (name: 'Germany', longitude: 10.5),
    'DK': (name: 'Denmark', longitude: 10.0),
    'EE': (name: 'Estonia', longitude: 26.0),
    'ES': (name: 'Spain', longitude: -3.7),
    'FI': (name: 'Finland', longitude: 26.0),
    'FR': (name: 'France', longitude: 2.2),
    'GB': (name: 'United Kingdom', longitude: -2.0),
    'GR': (name: 'Greece', longitude: 22.0),
    'HK': (name: 'Hong Kong', longitude: 114.2),
    'HU': (name: 'Hungary', longitude: 19.5),
    'ID': (name: 'Indonesia', longitude: 113.0),
    'IE': (name: 'Ireland', longitude: -8.0),
    'IL': (name: 'Israel', longitude: 35.0),
    'IN': (name: 'India', longitude: 79.0),
    'IS': (name: 'Iceland', longitude: -19.0),
    'IT': (name: 'Italy', longitude: 12.5),
    'JP': (name: 'Japan', longitude: 138.0),
    'KR': (name: 'South Korea', longitude: 127.8),
    'LT': (name: 'Lithuania', longitude: 24.0),
    'LU': (name: 'Luxembourg', longitude: 6.1),
    'LV': (name: 'Latvia', longitude: 24.9),
    'MX': (name: 'Mexico', longitude: -102.0),
    'MY': (name: 'Malaysia', longitude: 102.0),
    'NL': (name: 'Netherlands', longitude: 5.3),
    'NO': (name: 'Norway', longitude: 9.0),
    'NZ': (name: 'New Zealand', longitude: 174.0),
    'PH': (name: 'Philippines', longitude: 122.0),
    'PL': (name: 'Poland', longitude: 19.4),
    'PT': (name: 'Portugal', longitude: -8.2),
    'RO': (name: 'Romania', longitude: 25.0),
    'RS': (name: 'Serbia', longitude: 21.0),
    'SA': (name: 'Saudi Arabia', longitude: 45.0),
    'SE': (name: 'Sweden', longitude: 16.0),
    'SG': (name: 'Singapore', longitude: 103.8),
    'SK': (name: 'Slovakia', longitude: 19.7),
    'TH': (name: 'Thailand', longitude: 101.0),
    'TR': (name: 'Turkey', longitude: 35.0),
    'TW': (name: 'Taiwan', longitude: 121.0),
    'UA': (name: 'Ukraine', longitude: 31.2),
    'US': (name: 'United States', longitude: -98.5),
    'VN': (name: 'Vietnam', longitude: 108.3),
    'ZA': (name: 'South Africa', longitude: 24.7),
  };
}
