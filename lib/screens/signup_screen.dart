import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloodconnect/models/user_profile.dart';
import 'package:bloodconnect/services/user_service.dart';
import 'package:bloodconnect/main.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Hospital specific fields
  final _hospitalNameController = TextEditingController();
  final _hospitalCodeController = TextEditingController();

  String _selectedBloodType = 'A+';
  bool _canDonate = true;
  bool _isLoading = false;
  bool _isHospital = false;
  bool _isCheckingHospital = false;

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

  final List<String> basicHospitalDomains = [
    'hospital.com',
    'health.gov',
    'nhs.uk',
    'clinic.org',
  ];

  @override
  void initState() {
    super.initState();
    _prefillFromGoogleAuth();
  }

  Future<void> _prefillFromGoogleAuth() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _nameController.text = firebaseUser.displayName ?? '';
      _emailController.text = firebaseUser.email ?? '';

      // Detect if hospital email BEFORE showing form
      setState(() {
        _isCheckingHospital = true;
      });
      _isHospitalEmail(firebaseUser.email!).then((isHospital) {
        setState(() {
          _isHospital = isHospital;
          _isCheckingHospital = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _hospitalNameController.dispose();
    _hospitalCodeController.dispose();
    super.dispose();
  }

  Future<bool> _isHospitalEmail(String email) async {
    try {
      final db = ref.read(databaseServiceProvider);
      final emailDomain = email.split('@').last.toLowerCase();

      final result = await db.query(
        'SELECT COUNT(*) as count FROM hospital_domains WHERE domain = @domain AND active = TRUE',
        params: {'domain': emailDomain},
      );

      return (result.first['count'] as int) > 0;
    } catch (e) {
      // Fallback to basic check if database fails
      return basicHospitalDomains.any((hDomain) => email.contains(hDomain));
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userService = ref.read(userServiceProvider);
      final firebaseUser = FirebaseAuth.instance.currentUser;
      
      if (firebaseUser == null) {
        throw Exception('No authenticated user found');
      }

      final profile = _isHospital
          ? await _createHospitalProfile(userService, firebaseUser)
          : await _createRegularProfile(userService, firebaseUser);

      if (mounted) {
        final route = _getInitialRoute(profile);
        context.pushReplacement(route);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<UserProfile> _createHospitalProfile(
    UserService userService,
    User firebaseUser,
  ) async {
    return await userService.createCompleteProfile(
      firebaseUser,
      name: _hospitalNameController.text.trim(),
      email: firebaseUser.email!,
      phone: _phoneController.text.trim(),
      bloodType: '',  // Hospitals don't have blood type
      canDonate: false,
      accountType: 'hospital',
      hospitalName: _hospitalNameController.text.trim(),
      hospitalCode: _hospitalCodeController.text.trim(),
    );
  }

  Future<UserProfile> _createRegularProfile(
    UserService userService,
    User firebaseUser,
  ) async {
    return await userService.createCompleteProfile(
      firebaseUser,
      name: _nameController.text.trim(),
      email: firebaseUser.email!,
      phone: _phoneController.text.trim(),
      bloodType: _selectedBloodType,
      canDonate: _canDonate,
      accountType: 'regular',
    );
  }

  String _getInitialRoute(UserProfile profile) {
    if (profile.accountType == AccountType.hospital) {
      return '/hospital/dashboard';
    }
    return '/donor/home'; // All regular users start on donor home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isCheckingHospital
              ? 'Checking...'
              : (_isHospital
                    ? 'Hospital Registration'
                    : 'Complete Your Profile'),
        ),
        backgroundColor: Colors.red[600]!,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: _isCheckingHospital
              ? _buildLoadingIndicator()
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_isHospital) _buildRegularSignupForm(),
                      if (_isHospital) _buildHospitalSignupForm(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return  Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red.shade600),
            SizedBox(height: 20),
            Text('Checking hospital domain...'),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularSignupForm() {
    return Column(
      children: [
        // Profile Header
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
                radius: 40,
                backgroundColor: Colors.red[100]!,
                child: Icon(Icons.person, size: 40, color: Colors.red[600]!),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800]!,
                      ),
                    ),
                    Text(
                      'Tell us about yourself to help save lives',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),

        // Name Field
        _buildFormField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),

        // Email Field (read-only if from Google)
        _buildFormField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          readOnly: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),

        // Phone Field
        _buildFormField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),

        // Blood Type Field
        Container(
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
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Icon(Icons.opacity, color: Colors.red[600]!, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBloodType,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: bloodTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedBloodType = value!);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Can Donate Checkbox
        Container(
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
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Icon(
                  Icons.volunteer_activism,
                  color: Colors.red[600]!,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'I am willing to donate blood',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800]!,
                        ),
                      ),
                      Text(
                        'You can change this later in settings',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600]!,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: _canDonate,
                  onChanged: (value) {
                    setState(() => _canDonate = value ?? false);
                  },
                  activeColor: Colors.red[600]!,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Sign Up Button
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600]!,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Complete Registration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHospitalSignupForm() {
    return Column(
      children: [
        // Hospital Header
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
                radius: 40,
                backgroundColor: Colors.red[100]!,
                child: Icon(
                  Icons.local_hospital,
                  size: 40,
                  color: Colors.red[600]!,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hospital Registration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800]!,
                      ),
                    ),
                    Text(
                      'Register your hospital to join BloodConnect',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),

        // Hospital Name Field
        _buildFormField(
          controller: _hospitalNameController,
          label: 'Hospital Name',
          icon: Icons.local_hospital,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter hospital name';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),

        // Hospital Code Field
        _buildFormField(
          controller: _hospitalCodeController,
          label: 'Hospital Code (e.g., "CH")',
          icon: Icons.code,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter hospital code';
            }
            if (value.length > 10) {
              return 'Hospital code too long (max 10 characters)';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),

        // Email Field (read-only if from Google)
        _buildFormField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          readOnly: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),

        // Phone Field
        _buildFormField(
          controller: _phoneController,
          label: 'Contact Phone',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter contact phone';
            }
            return null;
          },
        ),
        const SizedBox(height: 30),

        // Register Button
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600]!,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Register Hospital',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
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
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.red[600]!, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[600]!, width: 2),
          ),
          contentPadding: const EdgeInsets.all(15),
        ),
        validator: validator,
      ),
    );
  }
}
