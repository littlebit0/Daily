import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';

class AnalyticsConsentPage extends ConsumerStatefulWidget {
  const AnalyticsConsentPage({
    required this.onCompleted,
    super.key,
    this.step = 0,
    this.stepCount = 1,
  });

  final VoidCallback onCompleted;
  final int step;
  final int stepCount;

  @override
  ConsumerState<AnalyticsConsentPage> createState() =>
      _AnalyticsConsentPageState();
}

class _AnalyticsConsentPageState extends ConsumerState<AnalyticsConsentPage> {
  var _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DailyOnboardingFrame(
        step: widget.step,
        stepCount: widget.stepCount,
        kicker: context.tr('Daily 개선 참여'),
        title: context.tr('더 완벽한 Daily를\n함께 만들어요.'),
        description: context.tr(
          '동의해주시면 실제 사용 흐름과 성능 문제를 익명으로 분석해 더 빠르고 안정적인 Daily를 만들 수 있어요.',
        ),
        primaryLabel: context.tr('익명 분석 허용'),
        onPrimary: _busy ? null : () => _complete(enabled: true),
        secondaryLabel: context.tr('나중에'),
        onSecondary: _busy ? null : () => _complete(enabled: false),
        busy: _busy,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    child: DailyFeatureCard(
                      icon: Icons.touch_app_outlined,
                      title: context.tr('사용 흐름'),
                      description: context.tr('화면과 기능 사용'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DailyFeatureCard(
                      icon: Icons.speed_outlined,
                      title: context.tr('성능 개선'),
                      description: context.tr('오류 범주와 응답 시간'),
                      color: DailyUi.purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DailyInfoCallout(
              text: context.tr(
                '일정 내용, 검색어, 계정 정보, 위치, 광고 식별자는 수집하지 않습니다. 언제든 설정에서 변경할 수 있어요.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DailyUi.destructive,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Future<void> _complete({required bool enabled}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(productAnalyticsProvider)
          .completeConsentPrompt(enabled: enabled);
      if (mounted) widget.onCompleted();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.tr('선택을 저장하지 못했습니다. 다시 시도해 주세요.');
        });
      }
    }
  }
}
