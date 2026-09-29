import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/services/security_service.dart';

class SecurityGuard extends ConsumerStatefulWidget {
  final Widget child;

  const SecurityGuard({super.key, required this.child});

  @override
  ConsumerState<SecurityGuard> createState() => _SecurityGuardState();
}

class _SecurityGuardState extends ConsumerState<SecurityGuard> {
  bool _isRooted = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final securityService = ref.read(securityServiceProvider);
    
    // Disable screenshot protection per user request
    await securityService.setScreenshotProtection(false);

    // Perform root check
    final isRooted = await securityService.isDeviceRooted();
    if (mounted) {
      setState(() {
        _isRooted = isRooted;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return widget.child;
    }

    if (_isRooted) {
      return Scaffold(
        backgroundColor: AppTheme.ctaBlack,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.shade900.withValues(alpha: 0.3),
                      border: Border.all(color: Colors.redAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.gpp_bad_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Security Alert: Device Rooted',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AGS Gold has detected that this device is rooted or jailbroken. '
                    'To protect your financial transactions and digital gold holdings, access is restricted on compromised operating systems.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _checkSecurity,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Re-check Device Security'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
