import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/custom_button.dart';
import '../../services/auth_service.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  String? _selectedFaculty;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  bool get _isPasswordValid {
    return _hasMinLength && _hasUppercase && _hasNumber && _hasSpecialChar;
  }

  // Faculty options
  final List<String> _faculties = [
    'FSKTM',
    'FKABB',
    'FKEE',
    'FKMP',
    'FPTV',
  ];

  // Validate UTHM email
  String? _validateUTHMEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!value.endsWith('@student.uthm.edu.my') &&
        !value.endsWith('@uthm.edu.my')) {
      return 'Please use your UTHM email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (!_isPasswordValid) {
      return 'Password does not meet all requirements';
    }
    return null;
  }

  // Check password requirements
  void _checkPasswordRequirements(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$&*]'));
    });
  }

  String? _validateStudentId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your student ID';
    }
    return null;
  }

  String? _validateFaculty(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select your faculty';
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Additional UTHM email validation
    final email = _emailController.text.trim();
    if (!email.endsWith('@student.uthm.edu.my') &&
        !email.endsWith('@uthm.edu.my')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use your official UTHM student email.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate faculty selection
    if (_selectedFaculty == null || _selectedFaculty!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your faculty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await _authService.signUpWithEmail(
        email: email,
        password: _passwordController.text,
        displayName: _fullNameController.text.trim(),
        studentId: _studentIdController.text.trim(),
        faculty: _selectedFaculty!,
      );

      // Get the user from credential
      final user = credential.user;
      if (user != null) {
        // Send email verification
        try {
          await user.sendEmailVerification();
          debugPrint('✅ Verification email sent to ${user.email}');
        } catch (e) {
          debugPrint('⚠️ Warning: Failed to send verification email: $e');
          // Continue even if verification email fails
        }
      }

      if (mounted) {
        // Navigate to Verify Email Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Add listener to password controller for real-time validation
    _passwordController.addListener(() {
      _checkPasswordRequirements(_passwordController.text);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Header
                Text(
                  'Join Your Campus\nMarketplace',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 40),

                // Full Name Field
                CustomTextField(
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  prefixIcon: Icons.person,
                  controller: _fullNameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // UTHM Email Field
                CustomTextField(
                  label: 'UTHM Email',
                  hint: 'your.email@student.uthm.edu.my',
                  prefixIcon: Icons.email,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateUTHMEmail,
                ),
                const SizedBox(height: 20),

                // Student ID Field
                CustomTextField(
                  label: 'Student ID',
                  hint: 'Enter your student ID',
                  prefixIcon: Icons.badge,
                  controller: _studentIdController,
                  keyboardType: TextInputType.text,
                  validator: _validateStudentId,
                ),
                const SizedBox(height: 20),

                // Faculty Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedFaculty,
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    hintText: 'Select your faculty',
                    filled: true,
                    fillColor: AppTheme.secondaryGrey,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
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
                      borderSide: const BorderSide(color: AppTheme.primaryYellow, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.school, color: AppTheme.textSecondary),
                    labelStyle: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                    hintStyle: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  items: _faculties.map((String faculty) {
                    return DropdownMenuItem<String>(
                      value: faculty,
                      child: Text(
                        faculty,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedFaculty = newValue;
                    });
                  },
                  validator: _validateFaculty,
                ),
                const SizedBox(height: 20),

                // Password Field
                CustomTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  prefixIcon: Icons.lock,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  suffixIcon: _obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  onSuffixIconTap: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                
                // Password Requirements
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPasswordRequirement(
                      'At least 8 characters',
                      _hasMinLength,
                    ),
                    const SizedBox(height: 8),
                    _buildPasswordRequirement(
                      'Contains at least one uppercase letter',
                      _hasUppercase,
                    ),
                    const SizedBox(height: 8),
                    _buildPasswordRequirement(
                      'Contains at least one number',
                      _hasNumber,
                    ),
                    const SizedBox(height: 8),
                    _buildPasswordRequirement(
                      'Contains at least one special character (!@#\$&*)',
                      _hasSpecialChar,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Terms Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                      activeColor: AppTheme.primaryYellow,
                      checkColor: AppTheme.black,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'I agree to the terms and conditions and confirm I am a student',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Sign Up Button
                CustomButton(
                  text: 'Sign Up',
                  onPressed: (_isPasswordValid && _agreeToTerms) ? _handleSignUp : null,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build password requirement row
  Widget _buildPasswordRequirement(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: isValid ? const Color(0xFFFEE500) : Colors.red, // Yellow for valid, red for invalid
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: isValid ? const Color(0xFFFEE500) : AppTheme.textSecondary, // Yellow for valid text
              fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
