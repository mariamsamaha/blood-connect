import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital.dart';
import 'package:bloodconnect/main.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  String _selectedBloodType = 'O+';
  int _unitsNeeded = 1;
  UrgencyLevel _urgencyLevel = UrgencyLevel.urgent;
  Hospital? _selectedHospital;
  List<Hospital> _hospitals = [];

  bool _isLoadingHospitals = true;
  bool _isSubmitting = false;

  final List<String> bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
    _prefillContactPhone();
  }

  Future<void> _loadHospitals() async {
    try {
      final requestService = ref.read(requestServiceProvider);
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final locationService = ref.read(locationServiceProvider);

      double? userLat;
      double? userLng;

      final pos = await locationService.getCurrentPosition();
      if (pos != null) {
        userLat = pos.latitude;
        userLng = pos.longitude;
      }

      final firebaseUser = authService.currentUser;
      if ((userLat == null || userLng == null) && firebaseUser != null) {
        final profile = await userService.getProfileByFirebaseUid(
          firebaseUser.uid,
        );
        if (profile != null) {
          userLat = profile.latitude;
          userLng = profile.longitude;
        }
      }

      // Fetch hospitals sorted by distance from user (GPS first, then profile)
      final hospitals = await requestService.getHospitals(
        userLatitude: userLat,
        userLongitude: userLng,
      );

      if (mounted) {
        setState(() {
          _hospitals = hospitals;
          _isLoadingHospitals = false;
          if (hospitals.isNotEmpty) {
            _selectedHospital = hospitals.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHospitals = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load hospitals: $e')));
      }
    }
  }

  Future<void> _prefillContactPhone() async {
    final authService = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);

    final firebaseUser = authService.currentUser;
    if (firebaseUser != null) {
      final profile = await userService.getProfileByFirebaseUid(
        firebaseUser.uid,
      );
      if (profile != null && mounted) {
        _contactPhoneController.text = profile.phone;
      }
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _descriptionController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHospital == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a hospital')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final requestService = ref.read(requestServiceProvider);
      final locationService = ref.read(locationServiceProvider);

      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) {
        throw Exception('Not authenticated');
      }

      final profile = await userService.getProfileByFirebaseUid(
        firebaseUser.uid,
      );
      if (profile == null) {
        throw Exception('Profile not found');
      }

      // Check if user already has an active request
      final existingRequest = await requestService.getActiveRequest(profile.id);
      if (existingRequest != null) {
        throw Exception(
          'You already have an active request (Code: ${existingRequest.displayCode}). '
          'Please cancel it first before creating a new one.',
        );
      }

      // Capture fresh location for accurate matching
      Position? currentPosition;
      double? requesterLat;
      double? requesterLng;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.red[600]),
                const SizedBox(height: 16),
                const Text('Getting your current location...'),
                const SizedBox(height: 8),
                Text(
                  'For accurate donor matching',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      }

      try {
        print('DEBUG: Attempting to get current GPS position...');
        currentPosition = await locationService.getCurrentPosition();
        requesterLat = currentPosition!.latitude;
        requesterLng = currentPosition.longitude;
        print('DEBUG: Got GPS position: $requesterLat, $requesterLng');

        if (mounted) Navigator.pop(context);
      } catch (e) {
        print('DEBUG: GPS Error: $e');
        if (mounted) Navigator.pop(context);

        // Location failed - ask user
        if (mounted) {
          final useHomeLocation = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.location_off, color: Colors.orange[600]),
                  const SizedBox(width: 12),
                  const Text('Location Unavailable'),
                ],
              ),
              content: Text(
                'Could not get your current location: $e\n\n'
                'We will use your saved location or the hospital location '
                'for matching donors.\n\n'
                'This may result in less accurate donor matches.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Go Back'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
                  child: const Text('Continue Anyway'),
                ),
              ],
            ),
          );

          if (useHomeLocation != true) {
            setState(() => _isSubmitting = false);
            return;
          }
        }

        // Use fallback location (null-safe)
        requesterLat = profile.latitude;
        requesterLng = profile.longitude;
      }

      // Create the request
      final request = await requestService.createRequest(
        requesterId: profile.id,
        bloodType: _selectedBloodType,
        unitsNeeded: _unitsNeeded,
        urgencyLevel: _urgencyLevel,
        hospitalId: _selectedHospital!.id,
        hospitalLat: _selectedHospital!.latitude,
        hospitalLng: _selectedHospital!.longitude,
        requesterLat: requesterLat,
        requesterLng: requesterLng,
        patientName: _patientNameController.text.trim().isEmpty
            ? null
            : _patientNameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
      );

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 32),
                const SizedBox(width: 12),
                const Text('Request Created!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your blood request has been created successfully.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Verification Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        request.displayCode,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[600],
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Show this code to the hospital staff',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.my_location, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        requesterLat != null
                            ? 'Matched ${request.nearbyDonorsCount} donors near your current location'
                            : 'Matched ${request.nearbyDonorsCount} donors near the hospital',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You will be notified when a donor accepts your request.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/recipient/home');
                },
                child: const Text('View Request Status'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create request: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create Blood Request'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingHospitals
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.red[100],
                              child: Icon(
                                Icons.bloodtype,
                                size: 32,
                                color: Colors.red[600],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Request Blood',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    'Fill in the details below',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      _buildSectionLabel('Blood Type Required'),
                      _buildBloodTypeSelector(),
                      const SizedBox(height: 20),

                      _buildSectionLabel('Units Needed'),
                      _buildUnitsSelector(),
                      const SizedBox(height: 20),

                      _buildSectionLabel('Urgency Level'),
                      _buildUrgencySelector(),
                      const SizedBox(height: 20),

                      _buildSectionLabel('Hospital'),
                      _buildHospitalSelector(),
                      const SizedBox(height: 20),

                      _buildSectionLabel('Patient Name (Optional)'),
                      _buildTextField(
                        controller: _patientNameController,
                        hintText: 'Enter patient name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),

                      _buildSectionLabel('Contact Phone'),
                      _buildTextField(
                        controller: _contactPhoneController,
                        hintText: 'Your contact number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Contact phone is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildSectionLabel('Additional Notes (Optional)'),
                      _buildTextField(
                        controller: _descriptionController,
                        hintText: 'Any additional information...',
                        icon: Icons.notes,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 30),

                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Create Request',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildBloodTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: bloodTypes.map((type) {
          final isSelected = _selectedBloodType == type;
          return ChoiceChip(
            label: Text(type),
            selected: isSelected,
            onSelected: (selected) {
              setState(() => _selectedBloodType = type);
            },
            selectedColor: Colors.red[600],
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUnitsSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.water_drop, color: Colors.red[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$_unitsNeeded ${_unitsNeeded == 1 ? 'unit' : 'units'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            onPressed: _unitsNeeded > 1
                ? () => setState(() => _unitsNeeded--)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.red[600],
          ),
          IconButton(
            onPressed: _unitsNeeded < 10
                ? () => setState(() => _unitsNeeded++)
                : null,
            icon: const Icon(Icons.add_circle_outline),
            color: Colors.red[600],
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildUrgencyOption(
            UrgencyLevel.routine,
            'Routine',
            'Planned procedure, flexible timing',
            Icons.schedule,
            Colors.blue,
          ),
          const Divider(height: 16),
          _buildUrgencyOption(
            UrgencyLevel.urgent,
            'Urgent',
            'Needed within 24 hours',
            Icons.warning_amber,
            Colors.orange,
          ),
          const Divider(height: 16),
          _buildUrgencyOption(
            UrgencyLevel.critical,
            'Critical',
            'Emergency - needed immediately',
            Icons.emergency,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyOption(
    UrgencyLevel level,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _urgencyLevel == level;
    return InkWell(
      onTap: () => setState(() => _urgencyLevel = level),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalSelector() {
    if (_hospitals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.local_hospital_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No hospitals available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hospitals.first.distanceKm != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4, left: 40),
              child: Row(
                children: [
                  Icon(Icons.near_me, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Sorted by distance (nearest first)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          DropdownButtonFormField<Hospital>(
            isExpanded: true,
            initialValue: _selectedHospital,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.local_hospital, color: Colors.red[600]),
              border: InputBorder.none,
            ),
            items: _hospitals.map((hospital) {
              return DropdownMenuItem<Hospital>(
                value: hospital,
                child: Text(
                  hospital.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (hospital) {
              setState(() => _selectedHospital = hospital);
            },
            validator: (value) {
              if (value == null) return 'Please select a hospital';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.red[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[600]!, width: 2),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: validator,
      ),
    );
  }
}
