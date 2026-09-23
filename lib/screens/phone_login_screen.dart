import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:go_router/go_router.dart';
import 'package:opem/core/design_tokens.dart';
import 'package:opem/core/router.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _PhoneAuthStep {
  enterPhone,
  verifyOtp,
}

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _PhoneAuthStep _step = _PhoneAuthStep.enterPhone;
  String _selectedCountryCode = '+91';
  String _fullPhoneNumber = '';

  Timer? _countdownTimer;
  int _countdownSeconds = 30;
  bool _canResend = false;
  bool _isProcessing = false;

  final List<Map<String, String>> _countryCodes = const [
    {'code': '+91', 'label': 'IN (+91)'},
    {'code': '+1', 'label': 'US/CA (+1)'},
    {'code': '+44', 'label': 'UK (+44)'},
    {'code': '+971', 'label': 'UAE (+971)'},
    {'code': '+65', 'label': 'SG (+65)'},
    {'code': '+61', 'label': 'AU (+61)'},
  ];

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdownSeconds = 30;
      _canResend = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        setState(() {
          _countdownSeconds = 0;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    final fullPhone = '$_selectedCountryCode$rawPhone';

    setState(() => _isProcessing = true);
    EasyLoading.show(status: 'Sending OTP code…');

    try {
      await authService.signInWithPhone(phone: fullPhone);
      if (!mounted) return;

      setState(() {
        _fullPhoneNumber = fullPhone;
        _step = _PhoneAuthStep.verifyOtp;
      });
      _startCountdown();
      EasyLoading.showSuccess('Verification code sent!');
    } on AuthException catch (e) {
      EasyLoading.showError(e.message);
    } catch (e) {
      EasyLoading.showError('Failed to send verification code. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      EasyLoading.dismiss();
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      EasyLoading.showToast('Please enter the 6-digit OTP code');
      return;
    }

    setState(() => _isProcessing = true);
    EasyLoading.show(status: 'Verifying code…');

    try {
      await authService.verifyPhoneOtp(
        phone: _fullPhoneNumber,
        token: otp,
      );
      if (!mounted) return;

      // Refresh profile data
      await context.read<UserProvider>().loadProfile();
      if (!mounted) return;

      EasyLoading.showSuccess('Welcome to B-Buys!');
      context.go(Routes.home);
    } on AuthException catch (e) {
      EasyLoading.showError(e.message);
    } catch (e) {
      EasyLoading.showError('Invalid code or verification failed.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      EasyLoading.dismiss();
    }
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend || _isProcessing) return;

    setState(() => _isProcessing = true);
    EasyLoading.show(status: 'Resending OTP…');

    try {
      await authService.resendPhoneOtp(phone: _fullPhoneNumber);
      if (!mounted) return;
      _startCountdown();
      EasyLoading.showSuccess('New code sent via SMS!');
    } on AuthException catch (e) {
      EasyLoading.showError(e.message);
    } catch (e) {
      EasyLoading.showError('Failed to resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_step == _PhoneAuthStep.verifyOtp) {
              setState(() {
                _step = _PhoneAuthStep.enterPhone;
                _countdownTimer?.cancel();
              });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: _step == _PhoneAuthStep.enterPhone
              ? _buildPhoneInputView(theme)
              : _buildOtpVerificationView(theme),
        ),
      ),
    );
  }

  Widget _buildPhoneInputView(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          // Icon badge
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
              ),
              child: const Icon(
                Icons.phone_iphone_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text(
            'Login with Phone',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We will send you a 6-digit one-time password (OTP) via SMS to verify your number.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Country Code + Phone Field Row
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            child: Row(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    items: _countryCodes.map((c) {
                      return DropdownMenuItem<String>(
                        value: c['code'],
                        child: Text(c['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCountryCode = val);
                    },
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Mobile number',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter your mobile number';
                      }
                      if (val.trim().length < 8) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Send OTP CTA
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Alternative options
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('OR', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textMuted)),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.email_outlined, size: 20),
            label: const Text('Continue with Email'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.primaryLight, width: 1.5),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Text(
          'Verify Mobile Number',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Code sent to ',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            Text(
              _fullPhoneNumber,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: AppColors.primary),
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit number',
              onPressed: () {
                setState(() {
                  _step = _PhoneAuthStep.enterPhone;
                  _countdownTimer?.cancel();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),

        // OTP Code Input Field
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
          child: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 16,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(
                letterSpacing: 16,
                color: AppColors.textMuted,
              ),
              border: InputBorder.none,
            ),
            onChanged: (val) {
              if (val.trim().length == 6) {
                _handleVerifyOtp();
              }
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Verify CTA
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'Verify & Proceed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Resend Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the SMS? ",
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (_canResend)
              TextButton(
                onPressed: _isProcessing ? null : _handleResendOtp,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Resend OTP', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              Text(
                'Resend in ${_countdownSeconds}s',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
