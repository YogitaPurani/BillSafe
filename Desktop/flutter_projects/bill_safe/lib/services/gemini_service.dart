import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/bill_scan.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const _model = 'gemini-2.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static Future<BillScan?> analyzeBill(File imageFile) async {
    if (_apiKey.isEmpty) {
      return _mockAnalysis();
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      const prompt = '''
Analyze this restaurant/shop bill image and extract:
1. Restaurant/shop name and location
2. All line items with amounts
3. GST number if present
4. GST rate applied
5. Service charge if present
6. Total amount

Then check for these issues:
- Service charge: illegal per MCA 2022 guidelines if mandatory
- GST rate: restaurants should charge 5% (not 12% or 18%)
- GST on service charge: illegal if service charge itself is illegal

Return ONLY valid JSON, no markdown:
{
  "restaurantName": "name",
  "category": "Restaurant/Medical/etc",
  "location": "city",
  "totalAmount": 0.0,
  "overchargedAmount": 0.0,
  "status": "fraud|clean|review",
  "gstinNumber": "number or null",
  "gstinVerified": true,
  "flaggedIssues": [
    {"title": "Issue Title", "description": "...", "amount": 0.0, "type": "illegal|wrongRate|invalid"}
  ],
  "breakdown": {
    "Food items": 0.0,
    "GST": 0.0,
    "Service charge": 0.0
  }
}
''';

      final response = await http.post(
        Uri.parse('$_endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'responseMimeType': 'application/json',
          }
        }),
      );

      if (response.statusCode != 200) {
        // Extract only the error message, never log the full body (may contain key echoes)
        String errorMsg = 'API error ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          errorMsg = errBody['error']?['message'] as String? ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';

      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}') + 1;
      final jsonStr = jsonStart >= 0 && jsonEnd > 0 ? text.substring(jsonStart, jsonEnd) : text;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _fromGeminiMap(map);
    } catch (e) {
      // Strip API key from any error string just in case
      final msg = e.toString().replaceAll(_apiKey, '[hidden]');
      throw Exception('Gemini error: $msg');
    }
  }

  static BillScan _fromGeminiMap(Map<String, dynamic> map) {
    BillStatus parseStatus(String s) {
      switch (s.toLowerCase()) {
        case 'fraud': return BillStatus.fraud;
        case 'clean': return BillStatus.clean;
        default: return BillStatus.review;
      }
    }

    IssueType parseType(String s) {
      switch (s.toLowerCase()) {
        case 'illegal': return IssueType.illegal;
        case 'wrongrate': return IssueType.wrongRate;
        default: return IssueType.invalid;
      }
    }

    final issues = (map['flaggedIssues'] as List? ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      return FlaggedIssue(
        title: m['title'] ?? '',
        description: m['description'] ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        type: parseType(m['type'] ?? ''),
      );
    }).toList();

    final breakdown = (map['breakdown'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    return BillScan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      restaurantName: map['restaurantName'] ?? 'Unknown',
      category: map['category'] ?? 'Other',
      location: map['location'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      overchargedAmount: (map['overchargedAmount'] as num?)?.toDouble() ?? 0.0,
      status: parseStatus(map['status'] ?? ''),
      scannedAt: DateTime.now(),
      gstinNumber: map['gstinNumber'] as String?,
      gstinVerified: map['gstinVerified'] as bool? ?? false,
      flaggedIssues: issues,
      breakdown: breakdown,
    );
  }

  static BillScan _mockAnalysis() {
    final isFraud = DateTime.now().second % 2 == 0;

    if (isFraud) {
      return BillScan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        restaurantName: 'Spice Garden',
        category: 'Restaurant',
        location: 'Mumbai',
        totalAmount: 892.0,
        overchargedAmount: 187.50,
        status: BillStatus.fraud,
        scannedAt: DateTime.now(),
        gstinNumber: '27AABCS1429B1ZB',
        gstinVerified: true,
        flaggedIssues: [
          const FlaggedIssue(
            title: 'Service Charge',
            description: 'Illegal — Not mandatory by law (MCA, 2022)',
            amount: 120.0,
            type: IssueType.illegal,
          ),
          const FlaggedIssue(
            title: 'GST Rate: 18% Applied',
            description: 'Correct rate is 5% for restaurants',
            amount: 45.90,
            type: IssueType.wrongRate,
          ),
          const FlaggedIssue(
            title: 'GST on Service Charge',
            description: 'Tax applied on an illegal charge',
            amount: 21.60,
            type: IssueType.invalid,
          ),
        ],
        breakdown: {
          'Food items': 600.0,
          'Service Charge': 120.0,
          'GST @ 18%': 129.60,
          'Packaging': 42.40,
        },
      );
    } else {
      return BillScan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        restaurantName: 'Meghana Foods',
        category: 'Restaurant',
        location: 'Bangalore',
        totalAmount: 734.0,
        overchargedAmount: 0.0,
        status: BillStatus.clean,
        scannedAt: DateTime.now(),
        gstinNumber: '29AABCM1234B1ZA',
        gstinVerified: true,
        flaggedIssues: [],
        breakdown: {
          'Food items': 680.0,
          'GST @ 5%': 34.0,
          'Packaging': 20.0,
        },
      );
    }
  }
}
