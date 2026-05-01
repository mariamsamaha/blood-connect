import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/app_text_field.dart';
import 'package:bloodconnect/widgets/blood_type_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Widget structure:
/// - Scaffold
///   - Animated step content (5 steps)
///   - Fixed bottom bar with step progress and Next/Submit
///   - Submit loading overlay
class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});
  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  int _step = 0;
  String _bloodType = 'O+';
  int _units = 1;
  UrgencyLevel _urgency = UrgencyLevel.urgent;
  Hospital? _hospital;
  final _patient = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  List<Hospital> _hospitals = const [];
  bool _loadingHospitals = true;
  bool _submitting = false;
  bool _locating = false;
  double? _requesterLat;
  double? _requesterLng;
  String? _locationNote;
  final _bloodTypes = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _prepareLocationAndHospitals();
    _prefillPhone();
  }

  Future<void> _prepareLocationAndHospitals() async {
    await _captureLocation(silent: true);
    await _loadHospitals();
  }

  Future<void> _prefillPhone() async {
    final auth = ref.read(authServiceProvider).currentUser;
    if (auth == null) return;
    final profile = await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
    if (!mounted || profile == null) return;
    _phone.text = profile.phone;
  }

  Future<void> _loadHospitals() async {
    try {
      final data = await ref.read(requestServiceProvider).getHospitals(
            userLatitude: _requesterLat,
            userLongitude: _requesterLng,
          );
      if (!mounted) return;
      setState(() {
        _hospitals = data;
        _hospital = data.isEmpty ? null : data.first;
        _loadingHospitals = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHospitals = false);
    }
  }

  Future<void> _captureLocation({bool silent = false}) async {
    if (!silent) {
      setState(() => _locating = true);
    } else {
      _locating = true;
    }
    try {
      final auth = ref.read(authServiceProvider).currentUser;
      final userService = ref.read(userServiceProvider);
      final locationService = ref.read(locationServiceProvider);

      final pos = await locationService.getCurrentPosition();
      if (pos != null) {
        _requesterLat = pos.latitude;
        _requesterLng = pos.longitude;
        _locationNote = 'Using current location for matching';
      } else if (auth != null) {
        final profile = await userService.getProfileByFirebaseUid(auth.uid);
        _requesterLat = profile?.latitude;
        _requesterLng = profile?.longitude;
        _locationNote = (_requesterLat != null && _requesterLng != null)
            ? 'Using saved profile location'
            : 'Location unavailable, hospital location will be used';
      }
    } catch (_) {
      _locationNote = 'Could not detect location, hospital location will be used';
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_hospital == null || _phone.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final auth = ref.read(authServiceProvider).currentUser;
      if (auth == null) return;
      final user = await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
      if (user == null) return;
      await ref.read(requestServiceProvider).createRequest(
            requesterId: user.id,
            bloodType: _bloodType,
            unitsNeeded: _units,
            urgencyLevel: _urgency,
            hospitalId: _hospital!.id,
            hospitalLat: _hospital!.latitude,
            hospitalLng: _hospital!.longitude,
            requesterLat: _requesterLat ?? user.latitude,
            requesterLng: _requesterLng ?? user.longitude,
            patientName: _patient.text.trim().isEmpty ? null : _patient.text.trim(),
            description: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            contactPhone: _phone.text.trim(),
          );
      if (!mounted) return;
      context.go('/recipient/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _patient.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _canProceedForStep();
    final inlineError = _validationMessageForStep();
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Create Request')),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stepTitle(_step),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (inlineError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    inlineError,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _StepContent(
                      key: ValueKey(_step),
                      step: _step,
                      bloodType: _bloodType,
                      units: _units,
                      urgency: _urgency,
                      hospital: _hospital,
                      hospitals: _hospitals,
                      loadingHospitals: _loadingHospitals,
                      bloodTypes: _bloodTypes,
                      patient: _patient,
                      phone: _phone,
                      notes: _notes,
                      locating: _locating,
                      locationNote: _locationNote,
                      requesterLat: _requesterLat,
                      requesterLng: _requesterLng,
                      onRefreshLocation: () async {
                        await _captureLocation();
                        await _loadHospitals();
                      },
                      onBloodType: (v) => setState(() => _bloodType = v),
                      onUnits: (v) => setState(() => _units = v.clamp(1, 10)),
                      onUrgency: (v) => setState(() => _urgency = v),
                      onHospital: (v) => setState(() => _hospital = v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomSheet: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, border: const Border(top: BorderSide(color: AppColors.divider))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                LinearProgressIndicator(value: (_step + 1) / 5, minHeight: 8, borderRadius: BorderRadius.circular(999)),
                const SizedBox(height: 10),
                AppButton.primary(
                  label: _step == 4 ? 'Submit Request' : 'Next',
                  onPressed: !canProceed
                      ? null
                      : (_step == 4
                            ? _submit
                            : () => setState(() => _step = (_step + 1).clamp(0, 4))),
                ),
              ]),
            ),
          ),
        ),
        if (_submitting)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Finding nearby donors...'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return 'Select Blood Type';
      case 1:
        return 'Select Quantity';
      case 2:
        return 'Select Urgency';
      case 3:
        return 'Select Hospital';
      default:
        return 'Patient Details';
    }
  }

  bool _canProceedForStep() => _validationMessageForStep() == null;

  String? _validationMessageForStep() {
    switch (_step) {
      case 0:
        return _bloodType.trim().isEmpty ? 'Please select a blood type' : null;
      case 1:
        return (_units < 1 || _units > 10)
            ? 'Quantity should be between 1 and 10 units'
            : null;
      case 2:
        return null;
      case 3:
        if (_loadingHospitals) return 'Loading nearby hospitals...';
        return _hospital == null ? 'Please select a hospital' : null;
      case 4:
        return _phone.text.trim().isEmpty ? 'Contact phone is required' : null;
      default:
        return null;
    }
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    super.key,
    required this.step,
    required this.bloodType,
    required this.units,
    required this.urgency,
    required this.hospital,
    required this.hospitals,
    required this.loadingHospitals,
    required this.bloodTypes,
    required this.patient,
    required this.phone,
    required this.notes,
    required this.onBloodType,
    required this.onUnits,
    required this.onUrgency,
    required this.onHospital,
    required this.locating,
    required this.locationNote,
    required this.requesterLat,
    required this.requesterLng,
    required this.onRefreshLocation,
  });
  final int step;
  final String bloodType;
  final int units;
  final UrgencyLevel urgency;
  final Hospital? hospital;
  final List<Hospital> hospitals;
  final bool loadingHospitals;
  final List<String> bloodTypes;
  final TextEditingController patient;
  final TextEditingController phone;
  final TextEditingController notes;
  final ValueChanged<String> onBloodType;
  final ValueChanged<int> onUnits;
  final ValueChanged<UrgencyLevel> onUrgency;
  final ValueChanged<Hospital?> onHospital;
  final bool locating;
  final String? locationNote;
  final double? requesterLat;
  final double? requesterLng;
  final Future<void> Function() onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    if (step == 0) {
      return GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: bloodTypes.map((t) => BloodTypeChip(type: t, selected: t == bloodType, onTap: () => onBloodType(t))).toList(),
      );
    }
    if (step == 1) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$units ${units == 1 ? 'Unit' : 'Units'}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text('Choose how many blood units are needed'),
              const SizedBox(height: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(onPressed: () => onUnits(units - 1), icon: const Icon(Icons.remove_circle_outline), iconSize: 34),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  alignment: Alignment.center,
                  child: Text(
                    '$units',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(onPressed: () => onUnits(units + 1), icon: const Icon(Icons.add_circle_outline), iconSize: 34),
              ]),
            ],
          ),
        ),
      );
    }
    if (step == 2) {
      return Column(children: [
        _UrgencyCard(level: UrgencyLevel.critical, selected: urgency == UrgencyLevel.critical, onTap: () => onUrgency(UrgencyLevel.critical)),
        const SizedBox(height: 12),
        _UrgencyCard(level: UrgencyLevel.urgent, selected: urgency == UrgencyLevel.urgent, onTap: () => onUrgency(UrgencyLevel.urgent)),
        const SizedBox(height: 12),
        _UrgencyCard(level: UrgencyLevel.routine, selected: urgency == UrgencyLevel.routine, onTap: () => onUrgency(UrgencyLevel.routine)),
      ]);
    }
    if (step == 3) {
      if (loadingHospitals) return const Center(child: CircularProgressIndicator());
      return ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_pin, color: AppColors.primaryRed, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationNote ?? 'Detecting location...',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (requesterLat != null && requesterLng != null)
                            Text(
                              '${requesterLat!.toStringAsFixed(4)}, ${requesterLng!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (locating)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: onRefreshLocation,
                        child: const Text('Refresh'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<Hospital>(
            value: hospital,
            decoration: const InputDecoration(
              labelText: 'Select Hospital (nearest first)',
            ),
            isExpanded: true,
            items: hospitals
                .map(
                  (h) => DropdownMenuItem<Hospital>(
                    value: h,
                    child: Text(
                      '${h.name} (${h.code}) • ${h.distanceKm?.toStringAsFixed(1) ?? '-'} km',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onHospital,
          ),
        ],
      );
    }
    return ListView(children: [
      AppTextField(controller: patient, label: 'Patient Name', hint: 'Optional'),
      const SizedBox(height: 16),
      AppTextField(controller: phone, label: 'Contact Phone', keyboardType: TextInputType.phone, hint: 'Required'),
      const SizedBox(height: 16),
      AppTextField(controller: notes, label: 'Notes', hint: 'Optional', maxLines: 4),
    ]);
  }
}

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard({required this.level, required this.selected, required this.onTap});
  final UrgencyLevel level;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final (icon, label, desc, color) = switch (level) {
      UrgencyLevel.critical => (Icons.emergency_rounded, 'Critical', 'Immediate need', AppColors.primaryRed),
      UrgencyLevel.urgent => (Icons.warning_amber_rounded, 'Urgent', 'Within 24 hours', AppColors.warning),
      UrgencyLevel.routine => (Icons.schedule_rounded, 'Routine', 'Planned donation', Colors.blue),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : AppColors.divider, width: selected ? 1.8 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text(desc, style: const TextStyle(color: AppColors.textSecondary))])),
        ]),
      ),
    );
  }
}

