/// Request blood types a donor blood type can fulfill.
const donorCanFulfillRequestTypes = <String, List<String>>{
  'O-': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  'O+': ['O+', 'A+', 'B+', 'AB+'],
  'A-': ['A-', 'A+', 'AB-', 'AB+'],
  'A+': ['A+', 'AB+'],
  'B-': ['B-', 'B+', 'AB-', 'AB+'],
  'B+': ['B+', 'AB+'],
  'AB-': ['AB-', 'AB+'],
  'AB+': ['AB+'],
};

/// Donor blood types that can fulfill a request needing [requestBloodType].
List<String> donorBloodTypesCompatibleWith(String requestBloodType) {
  return donorCanFulfillRequestTypes.entries
      .where((e) => e.value.contains(requestBloodType))
      .map((e) => e.key)
      .toList();
}
