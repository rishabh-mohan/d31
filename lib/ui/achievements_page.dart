/// Achievements (MM-03..07): University, Campaign and Other tabs over one
/// All / Incomplete / Complete filter.
///
/// University counts are this account's own enrollments (the original's
/// were online totals). A university is complete once enrolled in.
/// Campaigns are the installed packs, with their endings from the account
/// catalog; Other is the five achievements the capture shows that d30mode
/// can track (Baby Steps needs the Tutorial, which is not ported).
///
/// A full page under the Home menu header, like Records and Puzzles (TODO
/// 94); it used to be a sheet over Home.
library;

import 'package:flutter/material.dart';

import '../engine/account_catalog.dart';
import '../engine/account_store.dart';
import '../engine/pack.dart';
import 'account_widgets.dart';
import 'home_pages.dart';
import 'home_screen.dart';
import 'pack_image.dart';

enum _Filter {
  all('All'),
  incomplete('Incomplete'),
  complete('Complete');

  final String label;
  const _Filter(this.label);

  bool keeps(bool done) => switch (this) {
    all => true,
    incomplete => !done,
    complete => done,
  };
}

class AchievementsPage extends StatefulWidget {
  /// Installed campaigns, carrying the Settings university set.
  final List<ContentPack> campaigns;
  const AchievementsPage({super.key, required this.campaigns});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  int _tab = 0;
  _Filter _filter = _Filter.all;
  bool _filterOpen = false;
  String _region = 'korea';

  Account get account => AccountStore.current;
  AccountCatalog get catalog => AccountStore.catalog;

  @override
  Widget build(BuildContext context) {
    return MenuPage(
      title: 'Achievements',
      wash: .8,
      body: (context, u) => Stack(
        children: [
          Column(
            children: [
              _tabs(u),
              SizedBox(height: 10 * u),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 8 * u),
                  child: _filterButton(u),
                ),
              ),
              SizedBox(height: 10 * u),
              Expanded(
                child: switch (_tab) {
                  0 => _universities(u),
                  1 => _campaigns(u),
                  _ => _others(u),
                },
              ),
            ],
          ),
          if (_filterOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _filterOpen = false),
              ),
            ),
          if (_filterOpen)
            Positioned(
              top: 103 * u,
              right: 8 * u,
              width: 121 * u,
              child: _filterMenu(u),
            ),
        ],
      ),
    );
  }

  Widget _tabs(double u) => Row(
    children: [
      for (final (i, label) in ['University', 'Campaign', 'Other'].indexed)
        Expanded(
          child: InkWell(
            key: ValueKey('ach-tab-$label'),
            onTap: () => setState(() {
              _tab = i;
              _filterOpen = false;
            }),
            child: Container(
              height: 46 * u,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _tab == i ? HomeColors.orange : Colors.transparent,
                    width: 2.5 * u,
                  ),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16 * u,
                  color: _tab == i ? HomeColors.ink : const Color(0xFF6B625A),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _filterButton(double u) => GestureDetector(
    key: const ValueKey('ach-filter'),
    onTap: () => setState(() => _filterOpen = !_filterOpen),
    child: Container(
      width: 121 * u,
      height: 37 * u,
      // Clip so the orange arrow cell fills to the rounded border.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HomeColors.paper,
        borderRadius: BorderRadius.circular(8 * u),
        border: Border.all(color: HomeColors.orange, width: 2 * u),
      ),
      // Stretch so the arrow cell spans the pill's full inner height, not
      // just its icon's (TODO 110).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Text(
                _filter.label,
                style: TextStyle(fontSize: 15 * u, color: HomeColors.ink),
              ),
            ),
          ),
          Container(
            width: 25 * u,
            color: HomeColors.orange,
            child: Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: 26 * u,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _filterMenu(double u) => Container(
    decoration: BoxDecoration(
      color: HomeColors.cardFill,
      borderRadius: BorderRadius.circular(8 * u),
      border: Border.all(color: HomeColors.orange, width: 2 * u),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final f in _Filter.values)
          InkWell(
            key: ValueKey('ach-filter-${f.name}'),
            onTap: () => setState(() {
              _filter = f;
              _filterOpen = false;
            }),
            child: SizedBox(
              height: 44 * u,
              child: Center(
                child: Text(
                  f.label,
                  style: TextStyle(fontSize: 15 * u, color: HomeColors.ink),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  // ---- University ------------------------------------------------------

  static const _regions = {
    'korea': 'Korea',
    'special': 'Special',
    'global': 'Global',
    'taiwan': 'Taiwan',
  };

  Widget _universities(double u) {
    // Names and colours follow the Settings set where a pack renames them.
    final names = <int, University>{
      for (final pack in widget.campaigns) ...pack.admissions.universities,
    };
    final list = [
      for (final uni in catalog.universities)
        if (uni.region == _region &&
            _filter.keeps((account.enrollments[uni.id] ?? 0) > 0))
          uni,
    ];
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 13 * u),
          child: Container(
            height: 35 * u,
            decoration: BoxDecoration(
              color: HomeColors.cardFill,
              borderRadius: BorderRadius.circular(7 * u),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x334A2B10),
                  blurRadius: 4 * u,
                  offset: Offset(0, 2 * u),
                ),
              ],
            ),
            child: Row(
              children: [
                for (final e in _regions.entries)
                  Expanded(
                    child: GestureDetector(
                      key: ValueKey('region-${e.key}'),
                      onTap: () => setState(() => _region = e.key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _region == e.key ? HomeColors.orange : null,
                          borderRadius: BorderRadius.circular(7 * u),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 14 * u,
                            color: _region == e.key
                                ? Colors.white
                                : HomeColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 14 * u),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(8 * u, 4 * u, 8 * u, 24 * u),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 17 * u,
              crossAxisSpacing: 17 * u,
              childAspectRatio: 178 / 177,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final uni = list[i];
              final renamed = names[uni.id];
              return _UniversityCard(
                u: u,
                name: renamed?.name ?? uni.name,
                colorCode: renamed?.colorCode ?? uni.colorCode,
                crest: renamed?.crestPath ?? uni.crest,
                stars: uni.stars,
                enrollments: account.enrollments[uni.id] ?? 0,
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- Campaign --------------------------------------------------------

  Widget _campaigns(double u) {
    final cards = <Widget>[];
    final seen = <int>{};
    for (final pack in widget.campaigns) {
      final story = pack.manifest.storyId;
      if (story == null || !seen.add(story)) continue;
      final endings = catalog.endingsOf(story);
      if (endings.isEmpty) continue;
      final reached = endings.where((e) => account.endings.contains(e.code));
      final done = reached.length == endings.length;
      if (!_filter.keeps(done)) continue;
      final remaining = endings
          .where((e) => !account.endings.contains(e.code))
          .fold<int>(0, (sum, e) => sum + e.cookies);
      final portrait = pack.characters.values
          .where((c) => c.isDefault)
          .firstOrNull
          ?.portrait;
      cards.add(
        _CampaignCard(
          key: ValueKey('campaign-$story'),
          u: u,
          title: catalog.stories[story] ?? pack.manifest.name,
          portrait: portrait,
          reached: reached.length,
          total: endings.length,
          cookies: remaining,
          onTap: () =>
              pushOverlay<void>(context, _EndingsList(endings: endings)),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.fromLTRB(8 * u, 4 * u, 8 * u, 24 * u),
      mainAxisSpacing: 17 * u,
      crossAxisSpacing: 17 * u,
      childAspectRatio: 178 / 178,
      children: cards,
    );
  }

  // ---- Other -----------------------------------------------------------

  Widget _others(double u) {
    final list = [
      for (final a in AchievementInfo.all)
        if (_filter.keeps(account.achievementDone(a))) a,
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(8 * u, 4 * u, 8 * u, 24 * u),
      children: [
        for (final a in list)
          Padding(
            padding: EdgeInsets.only(bottom: 17 * u),
            child: _AchievementCard(u: u, info: a, account: account),
          ),
      ],
    );
  }
}

Color _hex(String? code, Color fallback) {
  final v = int.tryParse(code ?? '', radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

class _UniversityCard extends StatelessWidget {
  final double u;
  final String name;
  final String? colorCode;
  final String crest;
  final double stars;
  final int enrollments;

  const _UniversityCard({
    required this.u,
    required this.name,
    required this.colorCode,
    required this.crest,
    required this.stars,
    required this.enrollments,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hex(colorCode, HomeColors.orange);
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: .16), Colors.white),
        borderRadius: BorderRadius.circular(9 * u),
        border: Border.all(color: color, width: 3 * u),
        boxShadow: [
          BoxShadow(
            color: const Color(0x334A2B10),
            blurRadius: 4 * u,
            offset: Offset(0, 2.5 * u),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(6 * u, 6 * u, 6 * u, 8 * u),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8 * u, vertical: 2 * u),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20 * u),
            ),
            child: _Stars(u: u, stars: stars),
          ),
          SizedBox(height: 5 * u),
          Expanded(
            child: PackImage(
              path: crest,
              fit: BoxFit.contain,
              placeholder: Icon(Icons.school, color: color, size: 60 * u),
            ),
          ),
          SizedBox(height: 6 * u),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              style: TextStyle(fontSize: 14 * u, color: HomeColors.ink),
            ),
          ),
          Text(
            '# Enrollments $enrollments',
            style: TextStyle(fontSize: 14 * u, color: HomeColors.ink),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double u;
  final double stars;
  const _Stars({required this.u, required this.stars});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < stars.floor(); i++)
        SizedBox.square(
          dimension: 11 * u,
          child: const PackImage(
            path: 'kss/images/univ_star.png',
            fit: BoxFit.contain,
          ),
        ),
      if (stars % 1 >= .5)
        SizedBox.square(
          dimension: 11 * u,
          child: const PackImage(
            path: 'kss/images/univ_half_star.png',
            fit: BoxFit.contain,
          ),
        ),
    ],
  );
}

class _CampaignCard extends StatelessWidget {
  final double u;
  final String title;
  final String? portrait;
  final int reached;
  final int total;
  final int cookies;
  final VoidCallback onTap;

  const _CampaignCard({
    super.key,
    required this.u,
    required this.title,
    required this.portrait,
    required this.reached,
    required this.total,
    required this.cookies,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = reached == total;
    const green = Color(0xFF4CA846);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: HomeColors.cardFill,
          borderRadius: BorderRadius.circular(9 * u),
          border: Border.all(color: HomeColors.orange, width: 4 * u),
          boxShadow: [
            BoxShadow(
              color: const Color(0x334A2B10),
              blurRadius: 4 * u,
              offset: Offset(0, 2.5 * u),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(6 * u, 14 * u, 6 * u, 8 * u),
        child: Column(
          children: [
            Expanded(
              child: PackImage(
                path: portrait,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
            SizedBox(height: 6 * u),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  if (done) ...[
                    DoneCheck(size: 15 * u),
                    SizedBox(width: 4 * u),
                  ],
                  Text(
                    title,
                    style: TextStyle(fontSize: 15.5 * u, color: HomeColors.ink),
                  ),
                ],
              ),
            ),
            if (!done && cookies > 0)
              CookieAmount(u: u, amount: cookies, size: 12),
            Text(
              '$reached/$total',
              style: TextStyle(
                fontSize: 15.5 * u,
                color: done ? green : HomeColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MM-06: the campaign's endings, cookie reward or green check.
class _EndingsList extends StatelessWidget {
  final List<EndingInfo> endings;
  const _EndingsList({required this.endings});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final u = box.maxWidth / 390;
        final reached = AccountStore.current.endings;
        return Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              10 * u,
              box.maxHeight * .16,
              10 * u,
              box.maxHeight * .13,
            ),
            child: ChildPanel(
              u: u,
              cornerClose: true,
              child: Column(
                children: [
                  SizedBox(height: 22 * u),
                  Text(
                    'Endings List',
                    style: TextStyle(
                      fontSize: 23 * u,
                      fontWeight: FontWeight.bold,
                      color: HomeColors.ink,
                    ),
                  ),
                  SizedBox(height: 10 * u),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        28 * u,
                        4 * u,
                        28 * u,
                        20 * u,
                      ),
                      children: [
                        for (final e in endings)
                          Padding(
                            padding: EdgeInsets.only(bottom: 14 * u),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * u,
                                vertical: 9 * u,
                              ),
                              decoration: BoxDecoration(
                                color: HomeColors.cardFill,
                                borderRadius: BorderRadius.circular(8 * u),
                                border: Border.all(
                                  color: HomeColors.outline,
                                  width: 2 * u,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0x334A2B10),
                                    blurRadius: 3 * u,
                                    offset: Offset(0, 2 * u),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.name,
                                      style: TextStyle(
                                        fontSize: 16.5 * u,
                                        color: HomeColors.ink,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8 * u),
                                  if (reached.contains(e.code))
                                    DoneCheck(size: 22 * u)
                                  else if (e.cookies > 0)
                                    CookieAmount(
                                      u: u,
                                      amount: e.cookies,
                                      size: 14,
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
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

class _AchievementCard extends StatelessWidget {
  final double u;
  final AchievementInfo info;
  final Account account;
  const _AchievementCard({
    required this.u,
    required this.info,
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    final done = account.achievementDone(info);
    final progress = account.achievementProgress(info).clamp(0, info.target);
    const green = Color(0xFF4CA846);
    return Container(
      height: 96 * u,
      padding: EdgeInsets.symmetric(horizontal: 10 * u),
      decoration: BoxDecoration(
        color: HomeColors.cardFill,
        borderRadius: BorderRadius.circular(8 * u),
        border: Border.all(color: HomeColors.outline, width: 2 * u),
        boxShadow: [
          BoxShadow(
            color: const Color(0x334A2B10),
            blurRadius: 3 * u,
            offset: Offset(0, 2 * u),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (done) ...[
                      DoneCheck(size: 17 * u),
                      SizedBox(width: 6 * u),
                    ],
                    Text(
                      info.title,
                      style: TextStyle(fontSize: 19 * u, color: HomeColors.ink),
                    ),
                  ],
                ),
                SizedBox(height: 8 * u),
                Text(
                  '${info.condition} $progress/${info.target}',
                  style: TextStyle(
                    fontSize: 14.5 * u,
                    color: done ? green : HomeColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (!done && info.cookies > 0)
            CookieAmount(u: u, amount: info.cookies, size: 15),
        ],
      ),
    );
  }
}
