/// Shared pieces of the Submit route: school colours and crests, star
/// ratings, the recommendation card, the compact school card and the small
/// pills they wear (HANDOFF sections 4 and 5).
library;

import 'package:flutter/material.dart';

import '../engine/account_store.dart';
import '../engine/admissions.dart';
import '../engine/game.dart';
import 'pack_image.dart';
import 'press_feedback.dart';

/// One design unit: 1.0 at the 393-wide reference phone, so sizes follow the
/// viewport instead of the capture's pixels.
double uOf(BuildContext context) =>
    (MediaQuery.sizeOf(context).width / 393).clamp(0.8, 1.5).toDouble();

const submitInk = Color(0xFF4A2508);
const submitOrange = Color(0xFFFF8B55);
const submitCoral = Color(0xFFE8484F);
const submitCream = Color(0xFFFFF7E8);
const submitGreen = Color(0xFF3DB83A);
const starGold = Color(0xFFF5B31B);

/// A university's own colour (`colorCode`, six hex digits), orange if absent.
Color schoolColor(University? u) {
  final hex = u?.colorCode?.replaceAll('#', '');
  final v = hex == null ? null : int.tryParse('FF$hex', radix: 16);
  return Color(v ?? 0xFFFF8B55);
}

/// Whether the account owns [universityId]'s badge: the badge is in this
/// run's chosen set (this build has no separate badge inventory).
bool ownsBadge(Game game, int universityId) =>
    game.state.badgeIds.contains(universityId);

class Crest extends StatelessWidget {
  final University? university;
  final double size;
  const Crest({super.key, required this.university, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: PackImage(
      path: university?.crestPath,
      fit: BoxFit.contain,
      placeholder: Icon(
        Icons.school,
        size: size * .7,
        color: schoolColor(university),
      ),
    ),
  );
}

/// Gold stars, with a half star for x.5.
class StarRow extends StatelessWidget {
  final double stars;
  final double size;
  const StarRow({super.key, required this.stars, required this.size});

  @override
  Widget build(BuildContext context) {
    final full = stars.floor();
    final half = stars - full >= .5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < full; i++)
          Icon(Icons.star_rounded, size: size, color: starGold),
        if (half) Icon(Icons.star_half_rounded, size: size, color: starGold),
      ],
    );
  }
}

class BadgeOwnedPill extends StatelessWidget {
  final double fontSize;
  const BadgeOwnedPill({super.key, this.fontSize = 11});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: fontSize * .8, vertical: 1),
    decoration: BoxDecoration(
      color: submitCoral,
      borderRadius: BorderRadius.circular(fontSize),
    ),
    child: Text(
      'Badge owned',
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The recommendation card: school-coloured border, pale tint, dark lower
/// shadow, star rank at the upper left, crest at the left, names and rate in
/// the middle and a small green Apply at the lower right.
class MajorCard extends StatelessWidget {
  final Game game;
  final Department department;
  final VoidCallback onApply;
  const MajorCard({
    super.key,
    required this.game,
    required this.department,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    final school = game.pack.admissions.universities[department.universityId];
    final color = schoolColor(school);
    final dark = Color.lerp(color, Colors.black, .35)!;
    final enrollments = AccountStore.current.majorEnrollments(department.id);
    return Container(
      key: ValueKey('major-card-${department.id}'),
      margin: EdgeInsets.fromLTRB(16 * u, 0, 16 * u, 14 * u),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, color, .12),
        borderRadius: BorderRadius.circular(12 * u),
        border: Border.all(color: dark, width: 2.5 * u),
        boxShadow: [
          BoxShadow(color: dark, offset: Offset(0, 4 * u)),
          BoxShadow(
            color: const Color(0x33000000),
            blurRadius: 6 * u,
            offset: Offset(0, 7 * u),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 10 * u,
            top: 8 * u,
            child: StarRow(stars: school?.stars ?? 0, size: 12 * u),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12 * u, 26 * u, 10 * u, 10 * u),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 76 * u,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Crest(university: school, size: 70 * u),
                      if (ownsBadge(game, department.universityId)) ...[
                        SizedBox(height: 6 * u),
                        BadgeOwnedPill(fontSize: 11 * u),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8 * u),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        school?.name ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (school?.name.length ?? 0) > 28
                              ? 15 * u
                              : 21 * u,
                          height: 1.1,
                          color: submitInk,
                        ),
                      ),
                      SizedBox(height: 3 * u),
                      Text(
                        department.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: department.name.length > 34
                              ? 12 * u
                              : 14 * u,
                          height: 1.15,
                          color: submitInk,
                        ),
                      ),
                      SizedBox(height: 5 * u),
                      Text(
                        'Acceptance Rate : ${game.displayedRate(department)}',
                        style: TextStyle(fontSize: 17 * u, color: submitInk),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '# Enrollments $enrollments',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13 * u,
                                fontStyle: FontStyle.italic,
                                color: submitInk,
                              ),
                            ),
                          ),
                          ApplyButton(
                            key: ValueKey('apply-${department.id}'),
                            onTap: onApply,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ApplyButton extends StatelessWidget {
  final VoidCallback onTap;
  const ApplyButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    return PressFeedback(
      travel: 2,
      child: Material(
        color: submitGreen,
        borderRadius: BorderRadius.circular(8 * u),
        child: InkWell(
          borderRadius: BorderRadius.circular(8 * u),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * u, vertical: 6 * u),
            child: Text(
              'Apply',
              style: TextStyle(fontSize: 15 * u, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Story ids as the "Available for admission in ..." overlay names them.
String storyLabel(int id) => switch (id) {
  16 => '31-Day Mode',
  20 => 'Retry Year',
  _ => 'Story $id',
};

/// The compact school card of Search within Schools: crest, name and
/// `enrollees : n`, a Badge owned ribbon over the top edge, darkened with an
/// availability notice when the story cannot apply there.
class SchoolCard extends StatelessWidget {
  final Game game;
  final University university;
  final double width;
  final VoidCallback? onTap;
  const SchoolCard({
    super.key,
    required this.game,
    required this.university,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    final color = schoolColor(university);
    final dark = Color.lerp(color, Colors.black, .3)!;
    final available = university.available;
    final enrollees = AccountStore.current.universityEnrollees(university.id);
    final radius = BorderRadius.circular(10 * u);
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PressFeedback(
            travel: 2,
            child: Container(
              key: ValueKey('school-${university.id}'),
              margin: EdgeInsets.only(top: 8 * u),
              decoration: BoxDecoration(
                color: Color.lerp(Colors.white, color, .1),
                borderRadius: radius,
                border: Border.all(color: dark, width: 2.5 * u),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x44000000),
                    blurRadius: 4 * u,
                    offset: Offset(0, 3 * u),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: available ? onTap : null,
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            4 * u,
                            10 * u,
                            4 * u,
                            7 * u,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Crest(university: university, size: 46 * u),
                              SizedBox(height: 4 * u),
                              SizedBox(
                                height: 30 * u,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: width - 8 * u,
                                      child: Text(
                                        university.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13 * u,
                                          height: 1.05,
                                          fontWeight: FontWeight.w700,
                                          color: submitInk,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 2 * u),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'enrollees : $enrollees',
                                  style: TextStyle(
                                    fontSize: 12 * u,
                                    color: submitInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!available)
                          Positioned.fill(
                            child: Container(
                              key: ValueKey('school-locked-${university.id}'),
                              padding: EdgeInsets.all(5 * u),
                              color: const Color(0xCC1A1A1A),
                              alignment: Alignment.center,
                              child: Text(
                                _unavailable(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11 * u,
                                  height: 1.15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (available && ownsBadge(game, university.id))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: BadgeOwnedPill(fontSize: 11 * u)),
            ),
        ],
      ),
    );
  }

  String _unavailable() {
    final stories = university.availableStories;
    if (stories.isEmpty) return 'Not available for admission in this story';
    return 'Available for admission in ${stories.map(storyLabel).join(' / ')}';
  }
}

/// The two-line app-bar style label buttons of the header.
class SubmitHeaderButton extends StatelessWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final double width;
  final Key? buttonKey;
  const SubmitHeaderButton({
    super.key,
    this.buttonKey,
    required this.child,
    required this.color,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    final edge = Color.lerp(color, Colors.black, .35)!;
    return Padding(
      padding: EdgeInsets.only(bottom: 4 * u),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10 * u),
          boxShadow: [
            BoxShadow(color: edge, offset: Offset(0, 4 * u)),
            BoxShadow(
              color: const Color(0x33000000),
              blurRadius: 6 * u,
              offset: Offset(0, 6 * u),
            ),
          ],
        ),
        child: PressFeedback(
          travel: 4 * u,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            width: width,
            height: 46 * u,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10 * u),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: buttonKey,
                borderRadius: BorderRadius.circular(10 * u),
                onTap: onTap,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
