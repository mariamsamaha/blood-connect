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
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
                      onMapLocationChanged: (lat, lng) {
                        setState(() {
                          _requesterLat = lat;
                          _requesterLng = lng;
                          _locationNote =
                              'Pinned location set from map for donor matching';
                        });
                      },
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
    required this.onMapLocationChanged,
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
  final void Function(double lat, double lng) onMapLocationChanged;

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
          _LocationMapPicker(
            latitude: requesterLat,
            longitude: requesterLng,
            onLocationChanged: onMapLocationChanged,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(locationNote ?? 'Location is used to sort hospitals by proximity'),
                    ),
                    if (locating)
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: onRefreshLocation,
                        child: const Text('Refresh'),
                      ),
                  ],
                ),
                if (requesterLat != null && requesterLng != null)
                  Text(
                    'Lat ${requesterLat!.toStringAsFixed(4)}, Lng ${requesterLng!.toStringAsFixed(4)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<Hospital>(
            initialValue: hospital,
            decoration: const InputDecoration(
              labelText: 'Hospital dropdown (nearest first)',
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

class _LocationMapPicker extends StatefulWidget {
  const _LocationMapPicker({
    required this.latitude,
    required this.longitude,
    required this.onLocationChanged,
  });

  final double? latitude;
  final double? longitude;
  final void Function(double lat, double lng) onLocationChanged;

  @override
  State<_LocationMapPicker> createState() => _LocationMapPickerState();
}

class _LocationMapPickerState extends State<_LocationMapPicker> {
  static const _fallback = LatLng(30.0444, 31.2357);
  GoogleMapController? _controller;
  LatLng? _currentTarget;

  @override
  void initState() {
    super.initState();
    _currentTarget = widget.latitude != null && widget.longitude != null
        ? LatLng(widget.latitude!, widget.longitude!)
        : _fallback;
  }

  @override
  void didUpdateWidget(covariant _LocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
      final updated = widget.latitude != null && widget.longitude != null
          ? LatLng(widget.latitude!, widget.longitude!)
          : _fallback;
      _currentTarget = updated;
      _controller?.animateCamera(CameraUpdate.newLatLng(updated));
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _currentTarget ?? _fallback;
    return Container(
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: target, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (c) => _controller = c,
            onCameraMove: (position) => _currentTarget = position.target,
            onCameraIdle: () {
              final current = _currentTarget;
              if (current == null) return;
              widget.onLocationChanged(current.latitude, current.longitude);
            },
          ),
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.location_pin,
                size: 40,
                color: AppColors.primaryRed,
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Drag map to pin location',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
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

