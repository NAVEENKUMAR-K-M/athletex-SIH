// lib/services/shared_data_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Shared models for AthleteX
class Athlete {
  String id;
  String name;
  String team;
  String avatarUrl;
  Map<String, dynamic> metadata;

  Athlete({
    required this.id,
    required this.name,
    this.team = '',
    this.avatarUrl = '',
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  Athlete copyWith({
    String? id,
    String? name,
    String? team,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) {
    return Athlete(
      id: id ?? this.id,
      name: name ?? this.name,
      team: team ?? this.team,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? Map.from(this.metadata),
    );
  }

  factory Athlete.fromMap(Map<String, dynamic> m) {
    return Athlete(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      team: m['team']?.toString() ?? '',
      avatarUrl: m['avatarUrl']?.toString() ?? '',
      metadata: Map<String, dynamic>.from(m['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'team': team,
      'avatarUrl': avatarUrl,
      'metadata': metadata,
    };
  }
}

/// Example assessment record
class Assessment {
  String id;
  String athleteId;
  String type; // e.g. 'endurance', 'speed'
  DateTime timestamp;
  Map<String, dynamic> metrics;

  Assessment({
    required this.id,
    required this.athleteId,
    required this.type,
    DateTime? timestamp,
    Map<String, dynamic>? metrics,
  })  : timestamp = timestamp ?? DateTime.now(),
        metrics = metrics ?? {};

  Assessment copyWith({
    String? id,
    String? athleteId,
    String? type,
    DateTime? timestamp,
    Map<String, dynamic>? metrics,
  }) {
    return Assessment(
      id: id ?? this.id,
      athleteId: athleteId ?? this.athleteId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      metrics: metrics ?? Map.from(this.metrics),
    );
  }
}

/// Camera/ML runtime state container (keeps minimal info so pages can listen)
class CameraMlState {
  bool isStreaming;
  String currentModel;
  Map<String, dynamic> lastPose; // or other ML outputs

  CameraMlState({
    this.isStreaming = false,
    this.currentModel = '',
    Map<String, dynamic>? lastPose,
  }) : lastPose = lastPose ?? {};
}

/// The central shared service (singleton) used across pages to keep data synced.
class SharedDataService extends ChangeNotifier {
  // Singleton pattern
  static final SharedDataService _instance = SharedDataService._internal();
  factory SharedDataService() => _instance;
  SharedDataService._internal();

  // --- Core data structures ---
  final Map<String, Athlete> _athletes = {};
  final Map<String, List<Assessment>> _assessmentsByAthlete = {};

  CameraMlState cameraMlState = CameraMlState();

  // Simple stream/async helpers if pages need streams
  final StreamController<void> _updateController = StreamController.broadcast();
  Stream<void> get updates => _updateController.stream;

  // --- Athlete CRUD ---
  List<Athlete> get athletes => _athletes.values.toList(growable: false);

  Athlete? athleteById(String id) => _athletes[id];

  void addOrUpdateAthlete(Athlete a, {bool notify = true}) {
    _athletes[a.id] = a;
    if (notify) {
      _notifyAll();
    }
  }

  void addOrUpdateAthletes(List<Athlete> list, {bool notify = true}) {
    for (var a in list) {
      _athletes[a.id] = a;
    }
    if (notify) _notifyAll();
  }

  void removeAthlete(String id) {
    _athletes.remove(id);
    _assessmentsByAthlete.remove(id);
    _notifyAll();
  }

  // --- Assessments ---
  List<Assessment> assessmentsForAthlete(String athleteId) {
    return List.unmodifiable(_assessmentsByAthlete[athleteId] ?? []);
  }

  void addAssessment(Assessment assessment, {bool notify = true}) {
    final list = _assessmentsByAthlete.putIfAbsent(assessment.athleteId, () => []);
    // simple replace if same id exists
    final idx = list.indexWhere((a) => a.id == assessment.id);
    if (idx >= 0) {
      list[idx] = assessment;
    } else {
      list.add(assessment);
    }
    if (notify) _notifyAll();
  }

  void setAssessmentsForAthlete(String athleteId, List<Assessment> list, {bool notify = true}) {
    _assessmentsByAthlete[athleteId] = List.from(list);
    if (notify) _notifyAll();
  }

  void deleteAssessment(String athleteId, String assessmentId) {
    final list = _assessmentsByAthlete[athleteId];
    if (list == null) return;
    list.removeWhere((a) => a.id == assessmentId);
    _notifyAll();
  }

  // --- Camera/ML state helpers ---
  void updateCameraStreaming(bool streaming) {
    cameraMlState.isStreaming = streaming;
    _notifyAll();
  }

  void updateCurrentModel(String model) {
    cameraMlState.currentModel = model;
    _notifyAll();
  }

  void updateLastPose(Map<String, dynamic> pose) {
    cameraMlState.lastPose = Map.from(pose);
    _notifyAll();
  }

  // --- Utility ---
  void _notifyAll() {
    try { _updateController.add(null); } catch (_) {}
    notifyListeners();
  }

  /// Clear everything (useful in dev/testing)
  void clearAll({bool notify = true}) {
    _athletes.clear();
    _assessmentsByAthlete.clear();
    cameraMlState = CameraMlState();
    if (notify) _notifyAll();
  }

  // Dispose when app shuts down (normally not called for the singleton)
  @override
  void dispose() {
    _updateController.close();
    super.dispose();
  }
}
