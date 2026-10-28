import 'package:flutter/material.dart';

/// The neutral stand-in for a character icon the pack does not have, or whose
/// file cannot be read: a grey badge with a question mark. It scales to
/// whatever box it is given.
class MissingIcon extends StatelessWidget {
  const MissingIcon({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'No icon',
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.square(
        dimension: 100,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFD9D2C8),
          ),
          child: const Center(
            child: Text(
              '?',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8A7765),
                height: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
