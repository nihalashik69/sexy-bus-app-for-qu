import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;
  ScheduleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getStopSchedule(String stopId) async {
    try {
      final doc = await _firestore.collection('stops').doc(stopId.toUpperCase()).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('ScheduleService error: $e');
      return null;
    }
  }

  Map<String, List<int>> getNextBuses(Map<String, dynamic> routesData) {
    final result = <String, List<int>>{};
    
    if (routesData['routes'] is Map<String, dynamic>) {
      final routes = routesData['routes'] as Map<String, dynamic>;
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      routes.forEach((routeName, dynamic times) {
        if (times is List) {
          final sortedTimes = times.whereType<int>().toList()..sort();

          final nextTimes = sortedTimes.where((t) => t > currentMinutes).toList();

          if (nextTimes.length >= 3) {
            result[routeName] = nextTimes.take(3).cast<int>().toList();
          } else if (sortedTimes.isNotEmpty) {
            final remaining = nextTimes.length;
            final needed = 3 - remaining;
            final combined = <int>[
              ...nextTimes,
              ...sortedTimes.take(needed),
            ];
            result[routeName] = combined;
          } else {
            result[routeName] = sortedTimes.take(3).cast<int>().toList();
          }
        }
      });
    }
    return result;
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '${displayHour.toString()}:${mins.toString().padLeft(2, '0')} $period';
  }

  int getMinutesUntilArrival(int busTime) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    var diff = busTime - currentMinutes;
    if (diff < 0) diff += 1440;
    return diff;
  }
}