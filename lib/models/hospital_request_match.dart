import 'package:bloodconnect/models/blood_request.dart';

class HospitalRequestMatch {
  final BloodRequest request;
  final String? donorName;
  final String? donorPhone;

  const HospitalRequestMatch({
    required this.request,
    this.donorName,
    this.donorPhone,
  });
}
