import 'package:flutter/material.dart';
import 'package:flutter_haptics/flutter_haptics.dart';
import 'package:flutter_haptics_showcase/src/config/themes/app_colors.dart';
import 'package:flutter_haptics_showcase/src/core/haptics/app_haptics.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/safe_animated_switcher.dart';
import 'package:flutter_haptics_showcase/src/core/widgets/shaker.dart';

/// One verdict per submit, one shake for the first problem.
class FormValidationDemo extends StatefulWidget {
  const FormValidationDemo({super.key});

  @override
  State<FormValidationDemo> createState() => _FormValidationDemoState();
}

class _FormValidationDemoState extends State<FormValidationDemo> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final ShakeController _emailShake = ShakeController();
  final ShakeController _passwordShake = ShakeController();

  String? _emailError;
  String? _passwordError;
  bool _submitted = false;
  bool _done = false;

  static String? _validateEmail(String value) =>
      _emailPattern.hasMatch(value.trim()) ? null : 'Enter a valid email';

  static String? _validatePassword(String value) =>
      value.length >= 8 ? null : 'At least 8 characters';

  /// After the first submit, errors update live — silently.
  void _revalidate(String _) {
    if (!_submitted) return;
    setState(() {
      _emailError = _validateEmail(_email.text);
      _passwordError = _validatePassword(_password.text);
    });
  }

  void _submit() {
    final emailError = _validateEmail(_email.text);
    final passwordError = _validatePassword(_password.text);
    setState(() {
      _submitted = true;
      _emailError = emailError;
      _passwordError = passwordError;
    });

    if (emailError != null) {
      FlutterHaptics.perform(AppHaptics.failure);
      _emailShake.shake();
      _emailFocus.requestFocus();
    } else if (passwordError != null) {
      FlutterHaptics.perform(AppHaptics.failure);
      _passwordShake.shake();
      _passwordFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      FlutterHaptics.perform(AppHaptics.success);
      setState(() => _done = true);
    }
  }

  void _reset() {
    FlutterHaptics.perform(AppHaptics.tap);
    _email.clear();
    _password.clear();
    setState(() {
      _submitted = false;
      _done = false;
      _emailError = null;
      _passwordError = null;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailShake.dispose();
    _passwordShake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeAnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _done
          ? Column(
              key: const ValueKey('done'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 48,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 12),
                Text('Signed in', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(_email.text.trim(), style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                TextButton(onPressed: _reset, child: const Text('Start over')),
              ],
            )
          : Column(
              key: const ValueKey('form'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Shaker(
                  controller: _emailShake,
                  child: TextField(
                    controller: _email,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    onChanged: _revalidate,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      errorText: _emailError,
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Shaker(
                  controller: _passwordShake,
                  child: TextField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onChanged: _revalidate,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      errorText: _passwordError,
                      prefixIcon: const Icon(Icons.key_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Try submitting it empty first. Typing stays silent.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
