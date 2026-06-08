import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/theme/app_theme.dart';
import 'package:bloodconnect/widgets/app_button.dart';
import 'package:bloodconnect/widgets/app_text_field.dart';
import 'package:bloodconnect/widgets/blood_type_chip.dart';
import 'package:bloodconnect/widgets/blood_type_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});
  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
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
  final _bloodTypes = const [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

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
    final profile =
        await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load hospitals. Check your connection.'),
        ),
      );
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
        _locationNote =
            (_requesterLat != null && _requesterLng != null)
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
      final user =
          await ref.read(userServiceProvider).getProfileByFirebaseUid(auth.uid);
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
            patientName:
                _patient.text.trim().isEmpty ? null : _patient.text.trim(),
            description:
                _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            contactPhone: _phone.text.trim(),
          );
      if (!mounted) return;
      context.go('/recipient/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
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
                Row(
                  children: List.generate(
                    5,
                    (i) => Expanded(
                      child: AnimatedContainer(
                        duration: AppAnimations.medium,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: i <= _step ? AppGradients.primary : null,
                          color: i <= _step ? null : AppColors.divider,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Step ${_step + 1} of 5',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: AppAnimations.medium,
                      builder: (context, value, child) {
                        return Text(
                          '${(value * 20).round()}%',
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (inlineError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            inlineError,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppAnimations.medium,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.03, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: const Border(
                  top: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AppButton.secondary(
                        label: 'Back',
                        onPressed: () =>
                            setState(() => _step = (_step - 1).clamp(0, 4)),
                        size: ButtonSize.md,
                      ),
                    ),
                  Expanded(
                    child: AppButton.primary(
                      label: _step == 4 ? 'Submit Request' : 'Continue',
                      onPressed: !canProceed
                          ? null
                          : (_step == 4
                              ? _submit
                              : () => setState(
                                    () => _step = (_step + 1).clamp(0, 4),
                                  )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_submitting)
          Container(
            color: Colors.black38,
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                elevation: 8,
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.primaryRed,
                      ),
                      const SizedBox(height: 16),
                      const Text('Finding nearby donors...'),
                    ],
                  ),
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
        return 'Blood Type';
      case 1:
        return 'Quantity';
      case 2:
        return 'Urgency';
      case 3:
        return 'Hospital';
      default:
        return 'Details';
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
      return SingleChildScrollView(
        child: Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.3,
              children: bloodTypes
                  .map(
                    (t) => BloodTypeChip(
                      type: t,
                      selected: t == bloodType,
                      onTap: () => onBloodType(t),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Center(
              child: BloodTypeWheel(selectedType: bloodType, size: 220),
            ),
          ],
        ),
      );
    }
    if (step == 1) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$units ${units == 1 ? 'Unit' : 'Units'}',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'How many blood units are needed?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () => onUnits(units - 1),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.remove_circle_outline,
                          size: 36,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 80,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      '$units',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () => onUnits(units + 1),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.add_circle_outline,
                          size: 36,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (step == 2) {
      return Column(
        children: [
          _UrgencyCard(
            level: UrgencyLevel.critical,
            selected: urgency == UrgencyLevel.critical,
            onTap: () => onUrgency(UrgencyLevel.critical),
          ),
          const SizedBox(height: 12),
          _UrgencyCard(
            level: UrgencyLevel.urgent,
            selected: urgency == UrgencyLevel.urgent,
            onTap: () => onUrgency(UrgencyLevel.urgent),
          ),
          const SizedBox(height: 12),
          _UrgencyCard(
            level: UrgencyLevel.routine,
            selected: urgency == UrgencyLevel.routine,
            onTap: () => onUrgency(UrgencyLevel.routine),
          ),
        ],
      );
    }
    if (step == 3) {
      if (loadingHospitals) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.primaryRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationNote ?? 'Detecting location...',
                            style: const TextStyle(fontWeight: FontWeight.w500),
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
          const SizedBox(height: 16),
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
                      '${h.name} (${h.code}) \u2022 ${h.distanceKm?.toStringAsFixed(1) ?? '-'} km',
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
    return ListView(
      children: [
        AppTextField(
          controller: patient,
          label: 'Patient Name',
          hint: 'Optional',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: phone,
          label: 'Contact Phone',
          hint: 'Required',
          keyboardType: TextInputType.phone,
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: notes,
          label: 'Notes',
          hint: 'Optional',
          icon: Icons.notes_rounded,
          maxLines: 4,
        ),
      ],
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final UrgencyLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, label, desc, color) = switch (level) {
      UrgencyLevel.critical => (
        Icons.emergency_rounded,
        'Critical',
        'Immediate need \u2014 Notify all compatible donors',
        AppColors.primaryRed,
      ),
      UrgencyLevel.urgent => (
        Icons.warning_amber_rounded,
        'Urgent',
        'Within 24 hours',
        AppColors.warning,
      ),
      UrgencyLevel.routine => (
        Icons.schedule_rounded,
        'Routine',
        'Planned donation, no rush',
        AppColors.info,
      ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: AppAnimations.medium,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.06)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8)]
              : AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
