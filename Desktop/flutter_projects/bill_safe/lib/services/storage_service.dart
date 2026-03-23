import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill_scan.dart';

class StorageService {
  static const _scansKey = 'bill_scans';

  static final _scanSavedController = StreamController<void>.broadcast();
  static Stream<void> get onScanSaved => _scanSavedController.stream;

  static Future<List<BillScan>> getScans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scansKey) ?? [];
    return raw.map((e) => BillScan.fromJson(e)).toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  static Future<void> saveScan(BillScan scan) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scansKey) ?? [];
    // Avoid duplicates
    raw.removeWhere((e) {
      try {
        return BillScan.fromJson(e).id == scan.id;
      } catch (_) {
        return false;
      }
    });
    raw.add(scan.toJson());
    await prefs.setStringList(_scansKey, raw);
    _scanSavedController.add(null);
  }

  static Future<void> deleteScan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scansKey) ?? [];
    raw.removeWhere((e) {
      try {
        return BillScan.fromJson(e).id == id;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_scansKey, raw);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scansKey);
  }

  static Future<Map<String, dynamic>> getMonthlySummary() async {
    final scans = await getScans();
    final now = DateTime.now();
    final monthScans = scans.where((s) =>
        s.scannedAt.year == now.year && s.scannedAt.month == now.month);
    final totalSaved = monthScans.fold<double>(
        0, (sum, s) => sum + s.overchargedAmount);
    final fraudCount = monthScans.where((s) => s.status == BillStatus.fraud).length;
    return {
      'totalSaved': totalSaved,
      'totalScanned': monthScans.length,
      'fraudCaught': fraudCount,
    };
  }
}
