import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GSTINResult {
  final bool isFormatValid;
  final String? stateName;
  final String? pan;
  final String? entityType;
  final bool isVerified; // true = confirmed in GST database
  final String? businessName;
  final String? gstStatus; // Active / Inactive / Cancelled
  final String? registrationDate;
  final String? constitutionOfBusiness;

  const GSTINResult({
    required this.isFormatValid,
    this.stateName,
    this.pan,
    this.entityType,
    required this.isVerified,
    this.businessName,
    this.gstStatus,
    this.registrationDate,
    this.constitutionOfBusiness,
  });
}

class GSTINService {
  static final RegExp _gstinRegex = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );

  static const Map<String, String> _stateCodes = {
    '01': 'Jammu & Kashmir',
    '02': 'Himachal Pradesh',
    '03': 'Punjab',
    '04': 'Chandigarh',
    '05': 'Uttarakhand',
    '06': 'Haryana',
    '07': 'Delhi',
    '08': 'Rajasthan',
    '09': 'Uttar Pradesh',
    '10': 'Bihar',
    '11': 'Sikkim',
    '12': 'Arunachal Pradesh',
    '13': 'Nagaland',
    '14': 'Manipur',
    '15': 'Mizoram',
    '16': 'Tripura',
    '17': 'Meghalaya',
    '18': 'Assam',
    '19': 'West Bengal',
    '20': 'Jharkhand',
    '21': 'Odisha',
    '22': 'Chhattisgarh',
    '23': 'Madhya Pradesh',
    '24': 'Gujarat',
    '25': 'Daman & Diu',
    '26': 'Dadra & Nagar Haveli',
    '27': 'Maharashtra',
    '28': 'Andhra Pradesh (old)',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman & Nicobar Islands',
    '36': 'Telangana',
    '37': 'Andhra Pradesh',
    '38': 'Ladakh',
  };

  static String _decodeEntityType(String char) {
    final code = char.codeUnitAt(0);
    if (code >= 49 && code <= 57) {
      return 'Proprietor / Company';
    } else {
      return 'LLP / Other Entity';
    }
  }

  static Future<GSTINResult> verify(String gstin) async {
    final trimmed = gstin.trim().toUpperCase();
    final isFormatValid = _gstinRegex.hasMatch(trimmed);

    if (!isFormatValid) {
      return const GSTINResult(isFormatValid: false, isVerified: false);
    }

    final stateCode = trimmed.substring(0, 2);
    final stateName = _stateCodes[stateCode];
    final pan = trimmed.substring(2, 12);
    final entityTypeChar = trimmed[12];
    final entityType = _decodeEntityType(entityTypeChar);

    // Try live lookup via GSTINCheck.co.in (free tier — add GSTIN_API_KEY to .env)
    final apiKey = dotenv.maybeGet('GSTIN_API_KEY') ?? '';
    if (apiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://sheet.gstincheck.co.in/check/$apiKey/$trimmed',
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final flag = body['flag'] as bool? ?? false;

          if (flag && body['data'] != null) {
            final data = body['data'] as Map<String, dynamic>;
            final businessName = (data['tradeName'] as String?)?.isNotEmpty == true
                ? data['tradeName'] as String
                : data['legalName'] as String?;
            final gstStatus = data['gstStatus'] as String?;
            final regDate = data['dateOfRegistration'] as String?;
            final constitution = data['constitutionOfBusiness'] as String?;

            return GSTINResult(
              isFormatValid: true,
              stateName: stateName,
              pan: pan,
              entityType: constitution ?? entityType,
              isVerified: true,
              businessName: businessName,
              gstStatus: gstStatus,
              registrationDate: regDate,
              constitutionOfBusiness: constitution,
            );
          }

          // flag == false means GSTIN not found in database
          if (body.containsKey('flag') && !flag) {
            return GSTINResult(
              isFormatValid: true,
              stateName: stateName,
              pan: pan,
              entityType: entityType,
              isVerified: false,
              gstStatus: 'Not Found',
            );
          }
        }
      } catch (_) {
        // Network error — fall through to format-only result
      }
    }

    // No API key or network failure: format is valid but not database-verified
    return GSTINResult(
      isFormatValid: true,
      stateName: stateName,
      pan: pan,
      entityType: entityType,
      isVerified: false, // honest — not confirmed via database
    );
  }
}
