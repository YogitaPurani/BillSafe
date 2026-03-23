import 'dart:convert';

enum BillStatus { fraud, clean, review }
enum IssueType { illegal, wrongRate, invalid }

class FlaggedIssue {
  final String title;
  final String description;
  final double amount;
  final IssueType type;

  const FlaggedIssue({
    required this.title,
    required this.description,
    required this.amount,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'amount': amount,
        'type': type.index,
      };

  factory FlaggedIssue.fromMap(Map<String, dynamic> map) => FlaggedIssue(
        title: map['title'],
        description: map['description'],
        amount: map['amount'],
        type: IssueType.values[map['type']],
      );
}

class BillScan {
  final String id;
  final String restaurantName;
  final String category;
  final String location;
  final double totalAmount;
  final double overchargedAmount;
  final BillStatus status;
  final DateTime scannedAt;
  final String? gstinNumber;
  final bool gstinVerified;
  final List<FlaggedIssue> flaggedIssues;
  final Map<String, double> breakdown;
  final String? imagePath;

  BillScan({
    required this.id,
    required this.restaurantName,
    required this.category,
    required this.location,
    required this.totalAmount,
    required this.overchargedAmount,
    required this.status, 
    required this.scannedAt,
    this.gstinNumber,
    required this.gstinVerified,
    required this.flaggedIssues,
    required this.breakdown,
    this.imagePath,
  });

  BillScan withImagePath(String path) => BillScan(
        id: id,
        restaurantName: restaurantName,
        category: category,
        location: location,
        totalAmount: totalAmount,
        overchargedAmount: overchargedAmount,
        status: status,
        scannedAt: scannedAt,
        gstinNumber: gstinNumber,
        gstinVerified: gstinVerified,
        flaggedIssues: flaggedIssues,
        breakdown: breakdown,
        imagePath: path,
      );

  String get statusLabel {
    switch (status) {
      case BillStatus.fraud:
        return 'FRAUD';
      case BillStatus.clean:
        return 'CLEAN';
      case BillStatus.review:
        return 'REVIEW';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'restaurantName': restaurantName,
        'category': category,
        'location': location,
        'totalAmount': totalAmount,
        'overchargedAmount': overchargedAmount,
        'status': status.index,
        'scannedAt': scannedAt.millisecondsSinceEpoch,
        'gstinNumber': gstinNumber,
        'gstinVerified': gstinVerified,
        'flaggedIssues': flaggedIssues.map((e) => e.toMap()).toList(),
        'breakdown': breakdown,
        'imagePath': imagePath,
      };

  String toJson() => jsonEncode(toMap());

  factory BillScan.fromMap(Map<String, dynamic> map) => BillScan(
        id: map['id'],
        restaurantName: map['restaurantName'],
        category: map['category'],
        location: map['location'],
        totalAmount: (map['totalAmount'] as num).toDouble(),
        overchargedAmount: (map['overchargedAmount'] as num).toDouble(),
        status: BillStatus.values[map['status']],
        scannedAt: DateTime.fromMillisecondsSinceEpoch(map['scannedAt']),
        gstinNumber: map['gstinNumber'],
        gstinVerified: map['gstinVerified'],
        flaggedIssues: (map['flaggedIssues'] as List)
            .map((e) => FlaggedIssue.fromMap(e))
            .toList(),
        breakdown: Map<String, double>.from(
          (map['breakdown'] as Map).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        ),
        imagePath: map['imagePath'] as String?,
      );

  factory BillScan.fromJson(String source) =>
      BillScan.fromMap(jsonDecode(source));
}
