/// University Collection (HANDOFF section 7), opened from the Submit route's
/// header: a tall cream modal with an orange title bar, an X, and three tabs.
///
/// Badge Effect lists the pack's university badges alphabetically with their
/// effects (the same wording the setup screen uses); Standard and Elite show
/// the schools as a three-column grid, bright when the badge is owned. The
/// recording's Standard/Elite label mismatch is not reproduced: the tab and
/// its heading always agree here.
library;

import 'package:flutter/material.dart';

import '../engine/admissions.dart';
import '../engine/game.dart';
import '../engine/pack.dart';
import 'home_screen.dart';
import 'press_feedback.dart';
import 'setup_screen.dart' show effectLabel;
import 'submit_widgets.dart';
import 'university_badge.dart';

class UniversityCollectionPanel extends StatefulWidget {
  final Game game;
  const UniversityCollectionPanel({super.key, required this.game});

  @override
  State<UniversityCollectionPanel> createState() =>
      _UniversityCollectionPanelState();
}

class _UniversityCollectionPanelState extends State<UniversityCollectionPanel> {
  int _tab = 0;
  static const _tabs = ['Badge Effect', 'Standard Mode', 'Elite Mode'];

  Game get game => widget.game;

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    return SafeArea(
      child: Center(
        child: Container(
          key: const ValueKey('university-collection'),
          margin: EdgeInsets.symmetric(horizontal: 14 * u, vertical: 24 * u),
          decoration: BoxDecoration(
            color: HomeColors.paper,
            borderRadius: BorderRadius.circular(12 * u),
            border: Border.all(color: HomeColors.orange, width: 4 * u),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                Container(
                  height: 48 * u,
                  color: HomeColors.orange,
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          'University Collection',
                          style: TextStyle(
                            fontSize: 21 * u,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4 * u,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          key: const ValueKey('collection-close'),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 30 * u,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: InkWell(
                          key: ValueKey('collection-tab-$i'),
                          onTap: () => setState(() => _tab = i),
                          child: Container(
                            height: 42 * u,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: i == _tab
                                      ? HomeColors.orange
                                      : Colors.transparent,
                                  width: 3 * u,
                                ),
                              ),
                            ),
                            child: Text(
                              _tabs[i],
                              style: TextStyle(
                                fontSize: 15 * u,
                                color: i == _tab
                                    ? HomeColors.orange
                                    : HomeColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: switch (_tab) {
                    0 => _effects(u),
                    1 => _grid(u, [UniversityCategory.korea]),
                    _ => _grid(u, [
                      UniversityCategory.special,
                      UniversityCategory.global,
                      UniversityCategory.taiwan,
                    ]),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _effects(double u) {
    final badges = game.pack.badges.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return ListView(
      padding: EdgeInsets.fromLTRB(14 * u, 8 * u, 14 * u, 16 * u),
      children: [
        Center(
          child: Text(
            '(Alphabetical order)',
            style: TextStyle(fontSize: 14 * u, color: HomeColors.ink),
          ),
        ),
        SizedBox(height: 8 * u),
        for (final b in badges) _badgeRow(u, b),
      ],
    );
  }

  Widget _badgeRow(double u, UniversityBadge b) {
    final color = badgeColor(b);
    final owned = ownsBadge(game, b.universityId);
    return Opacity(
      opacity: owned ? 1 : .6,
      child: Container(
        height: 84 * u,
        margin: EdgeInsets.only(bottom: 10 * u),
        padding: EdgeInsets.all(4 * u),
        decoration: BoxDecoration(
          color: Color.lerp(Colors.white, color, .09),
          borderRadius: BorderRadius.circular(14 * u),
          border: Border.all(color: color, width: 2 * u),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74 * u,
              child: UniversityBadgeView(pack: game.pack, id: b.universityId),
            ),
            SizedBox(width: 8 * u),
            Expanded(
              child: Text(
                b.effects.map(effectLabel).join('\n'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14 * u, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(double u, List<UniversityCategory> categories) {
    final catalog = game.pack.admissions;
    final schools = [for (final c in categories) ...catalog.inCategory(c)];
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12 * u, 10 * u, 12 * u, 16 * u),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10 * u,
        mainAxisSpacing: 10 * u,
        childAspectRatio: .86,
      ),
      itemCount: schools.length,
      itemBuilder: (context, i) {
        final s = schools[i];
        final color = schoolColor(s);
        final owned = ownsBadge(game, s.id);
        return PressFeedback(
          child: Opacity(
            opacity: owned ? 1 : .55,
            child: Container(
              padding: EdgeInsets.all(6 * u),
              decoration: BoxDecoration(
                color: Color.lerp(Colors.white, color, .12),
                borderRadius: BorderRadius.circular(14 * u),
                border: Border.all(color: color, width: 2 * u),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Crest(university: s, size: 80 * u),
                  ),
                  SizedBox(
                    height: 32 * u,
                    child: Center(
                      child: Text(
                        s.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12 * u,
                          height: 1.05,
                          color: HomeColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
