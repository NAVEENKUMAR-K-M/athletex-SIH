// lib/models/athlete_profiles.dart
import 'package:flutter/material.dart';
import '../services/shared_data_service.dart'; // adjust relative path if needed

/// MockAthleteProfiles
///
/// Keeps the same simple map-based API you had, but mirrors changes to the
/// app-wide SharedDataService so other pages stay in sync automatically.
///
/// Important:
/// - Each profile's 'id' uses the sport string by default (change if you prefer UUID).
/// - When updateAssessment(...) runs, it adds an Assessment to SharedDataService
///   using the sport string as athleteId. You can change that behavior to use
///   real athlete IDs if you store them elsewhere.
class MockAthleteProfiles {
  /// All profiles keyed by sport (or any id you prefer).
  static final Map<String, Map<String, dynamic>> profiles = {};

  // ---------- INTERNAL (safe creators) ----------
  static Map<String, dynamic> _ensureProfile(String sport) {
    return profiles.putIfAbsent(sport, () {
      final profile = <String, dynamic>{
        'id': sport, // default id; change if you have a distinct athlete id
        'name': sport, // replace later with real name if you have it
        'sport': sport,
        'level': 1,
        'xp': 0,
        'nextLevelXp': 1000,
        'rank': 0,
        'achievements': <Map<String, dynamic>>[],
        'stats': <String, dynamic>{
          'totalSessions': 0,
          'verifiedReps': 0,
          'personalBest': '-',
        },
        'assessments': <String, Map<String, dynamic>>{
          'height':        {'value': '-', 'date': '-'},
          'weight':        {'value': '-', 'date': '-'},
          'verticalJump':  {'value': '-', 'date': '-'},
          'shuttleRun':    {'value': '-', 'date': '-'},
          'sitUps':        {'value': '-', 'unit': 'reps/min', 'date': '-'},
          'enduranceRun':  {'value': '-', 'unit': '(2.4km)', 'date': '-'},
        },
        'performanceHistory': <Map<String, dynamic>>[],
        'dietPlan': <String, String>{},
        'workoutPlan': <String, String>{},
        'fitnessCertificate': <String, dynamic>{'status': '-'},
      };

      // Mirror newly created profile into SharedDataService
      try {
        final athlete = _mapToAthlete(profile);
        SharedDataService().addOrUpdateAthlete(athlete, notify: true);
      } catch (_) {
        // ignore mapping errors to keep mock robust
      }

      return profile;
    });
  }

  static Map<String, dynamic> _assessments(String sport) =>
      (_ensureProfile(sport)['assessments'] as Map<String, dynamic>);

  static Map<String, dynamic> _ensureAssessment(String sport, String key) {
    final a = _assessments(sport);
    a.putIfAbsent(key, () => {'value': '-', 'date': '-'});
    return a[key] as Map<String, dynamic>;
  }

  static String _today() {
    final d = DateTime.now();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  // ---------- PUBLIC (safe APIs) ----------
  /// Safe: returns a profile map, creating it if needed.
  /// Also ensures SharedDataService has the athlete entry.
  static Map<String, dynamic> getOrCreate(String sport) {
    final profile = _ensureProfile(sport);

    // Ensure SharedDataService has the latest metadata
    try {
      final athlete = _mapToAthlete(profile);
      SharedDataService().addOrUpdateAthlete(athlete, notify: false);
      // notify once after modifications if needed
      SharedDataService().notifyListeners();
    } catch (_) {
      // swallow mapping errors so mock remains reliable
    }

    return profile;
  }

  /// Update an assessment result (e.g. when a test completes).
  /// This updates the in-memory mock, pushes xp and performance history,
  /// and creates/updates an Assessment in SharedDataService so listeners update.
  static void updateAssessment(String sport, String key, String value, {String? unit}) {
    final e = _ensureAssessment(sport, key);
    e['value'] = value;
    e['date'] = _today();
    if (unit != null) e['unit'] = unit;

    _addXp(sport, 50);
    profiles[sport]!['performanceHistory'].add({
      'date': _today(),
      'exercise': key,
      'score': value,
    });

    // Mirror assessment into SharedDataService as an Assessment model
    try {
      final athleteId = profiles[sport]?['id']?.toString() ?? sport;
      final assessment = Assessment(
        id: '$athleteId-$key-${DateTime.now().millisecondsSinceEpoch}',
        athleteId: athleteId,
        type: key,
        timestamp: DateTime.now(),
        metrics: {
          'value': value,
          if (unit != null) 'unit': unit,
          'fromMock': true,
        },
      );
      SharedDataService().addAssessment(assessment);
      // Also update the athlete metadata copy inside SharedDataService
      final athlete = _mapToAthlete(profiles[sport]!);
      SharedDataService().addOrUpdateAthlete(athlete, notify: false);
      SharedDataService().notifyListeners();
    } catch (_) {
      // ignore if SharedDataService mapping fails
    }
  }

  static void bumpSession(String sport) {
    final stats = _ensureProfile(sport)['stats'] as Map<String, dynamic>;
    stats['totalSessions'] = (stats['totalSessions'] ?? 0) + 1;

    // mirror stat change into SharedDataService
    try {
      final athlete = _mapToAthlete(profiles[sport]!);
      SharedDataService().addOrUpdateAthlete(athlete);
    } catch (_) {}
  }

  static void _addXp(String sport, int xpGain) {
    final p = _ensureProfile(sport);
    p['xp'] = (p['xp'] ?? 0) + xpGain;
    if ((p['xp'] as int) >= (p['nextLevelXp'] as int)) {
      p['level'] = (p['level'] ?? 1) + 1;
      p['xp'] = 0;
      p['nextLevelXp'] = (p['nextLevelXp'] ?? 1000) + 500;
    }

    // Mirror xp change
    try {
      final athlete = _mapToAthlete(p);
      SharedDataService().addOrUpdateAthlete(athlete, notify: false);
      SharedDataService().notifyListeners();
    } catch (_) {}
  }

  // ---------- NULL-SAFE READ HELPERS ----------
  static String valueOf(String sport, String key) {
    final a = _assessments(sport)[key];
    if (a is Map && a['value'] != null) return a['value'].toString();
    return '-';
  }

  static String dateOf(String sport, String key) {
    final a = _assessments(sport)[key];
    if (a is Map && a['date'] != null) return a['date'].toString();
    return '-';
  }

  static String valueWithUnitOf(String sport, String key) {
    final a = _assessments(sport)[key];
    if (a is Map) {
      final v = (a['value'] ?? '-').toString();
      final u = (a['unit'] ?? '').toString();
      return u.isEmpty ? v : "$v $u";
    }
    return '-';
  }

  // ---------- HELPERS: mapping to SharedDataService models ----------
  static Athlete _mapToAthlete(Map<String, dynamic> profile) {
    // SharedDataService.Athlete expects: id, name, team, avatarUrl, metadata
    final id = profile['id']?.toString() ?? profile['sport']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    return Athlete(
      id: id,
      name: profile['name']?.toString() ?? profile['sport']?.toString() ?? 'Athlete',
      team: profile['team']?.toString() ?? '',
      avatarUrl: profile['avatarUrl']?.toString() ?? profile['avatar']?.toString() ?? '',
      metadata: Map<String, dynamic>.from(profile),
    );
  }
}
