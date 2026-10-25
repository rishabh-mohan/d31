/// The exam card: one large purple rounded card that fills the hand area on
/// exam day, one subject at a time (HANDOFF section 1). White paper-and-check
/// icon, the subject label centered below, a darker lower face and a shadow.
library;

import 'package:flutter/material.dart';

import 'press_feedback.dart';

class ExamCardButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  /// Height of the card face; the lower face sits under it.
  final double height;

  const ExamCardButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 300,
  });

  static const face = Color(0xFF7F3199);
  static const lower = Color(0xFF5A2270);
  static const _depth = 8.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: _depth),
    child: Semantics(
      button: true,
      label: '$label exam',
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(color: lower, offset: Offset(0, _depth)),
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 10,
                offset: Offset(0, _depth + 3),
              ),
            ],
          ),
          child: PressFeedback(
            travel: _depth,
            child: Material(
              color: face,
              borderRadius: BorderRadius.circular(26),
              child: InkWell(
                key: ValueKey('exam-card-$label'),
                borderRadius: BorderRadius.circular(26),
                onTap: onTap,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 112,
                        color: Color(0xFFF7EEFA),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 44,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
