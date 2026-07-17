import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/security/biometric_auth_service.dart';

final sensitiveEventsUnlockedProvider = StateProvider<bool>((ref) => false);

Future<bool> authenticateSensitiveEventAccess({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  if (ref.read(sensitiveEventsUnlockedProvider)) {
    return true;
  }

  final biometricAuth = BiometricAuthService();
  if (await biometricAuth.isAvailable()) {
    final authenticated = await biometricAuth.authenticate(
      localizedReason: '비공개 일정 내용을 보려면 인증이 필요합니다.',
    );
    if (authenticated) {
      return true;
    }
  }

  final repository = ref.read(settingsRepositoryProvider);
  final expectedLength = await repository.appLockPinLength();
  if (!context.mounted) {
    return false;
  }
  if (expectedLength == null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('인증 필요'),
        content: const Text('비공개 일정을 보려면 설정에서 앱 잠금 PIN을 먼저 설정해 주세요.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return false;
  }

  return await showDialog<bool>(
        context: context,
        builder: (context) => _SensitivePinDialog(
          expectedLength: expectedLength,
          verifier: repository.verifyAppLockPin,
        ),
      ) ??
      false;
}

class _SensitivePinDialog extends StatefulWidget {
  const _SensitivePinDialog({
    required this.expectedLength,
    required this.verifier,
  });

  final int expectedLength;
  final Future<bool> Function(String pin) verifier;

  @override
  State<_SensitivePinDialog> createState() => _SensitivePinDialogState();
}

class _SensitivePinDialogState extends State<_SensitivePinDialog> {
  var _pin = '';
  var _checking = false;
  var _error = '';

  void _appendDigit(String digit) {
    if (_checking || _pin.length >= widget.expectedLength) {
      return;
    }
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (_pin.length == widget.expectedLength) {
      unawaited(_verify());
    }
  }

  void _removeDigit() {
    if (_checking || _pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  Future<void> _verify() async {
    if (_checking || _pin.length != widget.expectedLength) {
      return;
    }
    final pin = _pin;
    setState(() => _checking = true);
    final verified = await widget.verifier(pin);
    if (!mounted) {
      return;
    }
    if (verified) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _pin = '';
      _checking = false;
      _error = 'PIN이 일치하지 않습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('비공개 일정 확인'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('앱 잠금 PIN을 입력하세요.'),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: List.generate(widget.expectedLength, (index) {
                final filled = index < _pin.length;
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: filled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            SizedBox(
              height: 24,
              child: Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            _PinKeypad(
              enabled: !_checking,
              onDigit: _appendDigit,
              onBackspace: _removeDigit,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        for (final digit in digits)
          digit.isEmpty
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: enabled ? () => onDigit(digit) : null,
                  child: Text(
                    digit,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
        IconButton(
          tooltip: '한 자리 지우기',
          onPressed: enabled ? onBackspace : null,
          icon: const Icon(Icons.backspace_outlined),
        ),
      ],
    );
  }
}
