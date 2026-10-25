/// The three tab bodies of the Submit route, and the state they share
/// (HANDOFF sections 4-6): Recommended Majors, Search within Schools and
/// Search Majors.
library;

import 'package:flutter/material.dart';

import '../engine/admissions.dart';
import '../engine/game.dart';
import 'press_feedback.dart';
import 'submit_widgets.dart';
import 'toast.dart';

/// Sort menu options. RECONSTRUCTED: the recording never opens the Sort menu,
/// so these three are chosen here (best odds first is the engine's own order).
enum SubmitSort {
  rateHigh('Acceptance rate: high to low'),
  rateLow('Acceptance rate: low to high'),
  name('Name');

  final String label;
  const SubmitSort(this.label);
}

/// The Submit route's shared state: filters, query and the open school. It
/// lives for the page, so the query and filters survive modal round trips and
/// tab switches. The draft itself lives in the engine (`game.draftSlots`).
class SubmitModel extends ChangeNotifier {
  final Game game;
  SubmitModel(this.game);

  bool hideApplied = true;
  RangeValues range = const RangeValues(20, 80);
  SubmitSort sort = SubmitSort.rateHigh;
  String query = '';
  UniversityCategory category = UniversityCategory.korea;

  /// The school whose majors the Search within Schools tab is showing.
  int? openSchool;

  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void changed() => notifyListeners();

  void setHideApplied(bool v) {
    hideApplied = v;
    notifyListeners();
  }

  void setRange(RangeValues v) {
    range = RangeValues(v.start.roundToDouble(), v.end.roundToDouble());
    notifyListeners();
  }

  void setSort(SubmitSort v) {
    sort = v;
    notifyListeners();
  }

  void setQuery(String v) {
    query = v;
    notifyListeners();
  }

  void setCategory(UniversityCategory c) {
    category = c;
    notifyListeners();
  }

  void openSchoolMajors(int? id) {
    openSchool = id;
    notifyListeners();
  }

  // --- lists ---------------------------------------------------------------

  List<Department> _sorted(List<Department> list) {
    final universities = game.pack.admissions.universities;
    String school(Department d) => universities[d.universityId]?.name ?? '';
    final copy = [...list];
    switch (sort) {
      case SubmitSort.rateHigh:
        // The engine already returns best odds first.
        return list;
      case SubmitSort.rateLow:
        final rates = {for (final d in copy) d.id: game.displayedRate(d)};
        copy.sort((a, b) {
          final c = rates[a.id]!.compareTo(rates[b.id]!);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      case SubmitSort.name:
        copy.sort((a, b) {
          final c = school(a).compareTo(school(b));
          return c != 0 ? c : a.name.compareTo(b.name);
        });
    }
    return copy;
  }

  List<Department> recommended() => _sorted(
    game.recommendedDepartments(
      minRate: range.start.round(),
      maxRate: range.end.round(),
      hideApplied: hideApplied,
    ),
  );

  List<Department> searched() =>
      _sorted(game.searchMajors(query, hideApplied: hideApplied));

  List<Department> majorsOf(int universityId) => [
    for (final d in game.pack.admissions.departmentsOf(universityId))
      if (game.isEligible(d)) d,
  ];

  // --- draft actions ---------------------------------------------------------

  String labelOf(Department d) =>
      '${game.pack.admissions.universities[d.universityId]?.name ?? ''} '
      '${d.name}';

  /// Apply on a card: puts the major in the first free slot with a toast, or
  /// says why it cannot be added.
  void apply(BuildContext context, Department d) {
    final problem = game.draftProblem(d);
    if (problem != null) {
      D30Toast.show(context, problem);
      return;
    }
    if (game.addToDraft(d.id) != null) {
      D30Toast.show(context, '${labelOf(d)} application available.');
    }
    notifyListeners();
  }

  /// Tapping a filled slot removes the candidate.
  void removeSlot(BuildContext context, int slot) {
    final id = game.draftSlots[slot];
    final d = id == null ? null : game.pack.admissions.departments[id];
    if (!game.removeFromDraft(slot)) return;
    if (d != null) {
      D30Toast.show(
        context,
        'You started writing and then deleted your ${labelOf(d)} application.',
      );
    }
    notifyListeners();
  }

  /// Auto Input: fills only the empty slots.
  void autoInput(BuildContext context) {
    final filled = game.autoFill();
    if (filled.isEmpty) {
      D30Toast.show(
        context,
        game.draftSlots.contains(null)
            ? 'No more majors to add.'
            : 'All candidate slots are filled.',
      );
    }
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Filter controls
// ---------------------------------------------------------------------------

/// The Sort box: a cream outlined rounded box with its own orange arrow
/// segment; tapping opens the option menu.
class SortBox extends StatelessWidget {
  final SubmitModel model;
  const SortBox({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    return PopupMenuButton<SubmitSort>(
      key: const ValueKey('sort-box'),
      tooltip: 'Sort',
      initialValue: model.sort,
      onSelected: model.setSort,
      itemBuilder: (_) => [
        for (final s in SubmitSort.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: Container(
        width: 108 * u,
        height: 40 * u,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10 * u),
          border: Border.all(color: submitOrange, width: 2 * u),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  'Sort',
                  style: TextStyle(fontSize: 18 * u, color: submitInk),
                ),
              ),
            ),
            Container(
              width: 34 * u,
              color: submitOrange,
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: Colors.white,
                size: 30 * u,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HideAppliedSwitch extends StatelessWidget {
  final SubmitModel model;
  const HideAppliedSwitch({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Hide Applied Universities',
              maxLines: 1,
              style: TextStyle(fontSize: 15 * u, color: submitInk),
            ),
          ),
        ),
        SizedBox(width: 6 * u),
        Switch(
          key: const ValueKey('hide-applied-switch'),
          value: model.hideApplied,
          onChanged: model.setHideApplied,
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? submitOrange
                : const Color(0xFF9E9E9E),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0xFFFFD2BC)
                : const Color(0xFFE2E2E2),
          ),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ],
    );
  }
}

class SortAndHideRow extends StatelessWidget {
  final SubmitModel model;
  const SortAndHideRow({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16 * u, 12 * u, 8 * u, 6 * u),
      child: Row(
        children: [
          SortBox(model: model),
          SizedBox(width: 10 * u),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: HideAppliedSwitch(model: model),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Acceptance Rate Range Setting : a% - b%", the two-thumb slider and the
/// numeric markers every 20.
class RangeSetting extends StatelessWidget {
  final SubmitModel model;
  const RangeSetting({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    final r = model.range;
    Widget mark(int v) => Text(
      '$v',
      style: TextStyle(
        fontSize: 14 * u,
        color: v >= r.start && v <= r.end
            ? submitOrange
            : const Color(0xFFFFC8B0),
      ),
    );
    return Column(
      children: [
        Text(
          'Acceptance Rate Range Setting : ${r.start.round()}% - ${r.end.round()}%',
          key: const ValueKey('range-caption'),
          style: TextStyle(fontSize: 14 * u, color: submitOrange),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5 * u,
            activeTrackColor: submitOrange,
            inactiveTrackColor: const Color(0xFFFFD9C7),
            rangeThumbShape: RoundRangeSliderThumbShape(
              enabledThumbRadius: 13 * u,
              elevation: 0,
              pressedElevation: 0,
            ),
            thumbColor: submitOrange,
            overlayColor: const Color(0x22FF8B55),
            rangeTickMarkShape: const RoundRangeSliderTickMarkShape(
              tickMarkRadius: 0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10 * u),
            child: RangeSlider(
              key: const ValueKey('rate-range'),
              values: r,
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: model.setRange,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22 * u),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final v in [0, 20, 40, 60, 80, 100]) mark(v),
            ],
          ),
        ),
        SizedBox(height: 14 * u),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recommended Majors
// ---------------------------------------------------------------------------

class RecommendedTab extends StatelessWidget {
  final SubmitModel model;
  const RecommendedTab({super.key, required this.model});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final rows = model.recommended();
      return CustomScrollView(
        key: const PageStorageKey('recommended-scroll'),
        slivers: [
          SliverToBoxAdapter(child: SortAndHideRow(model: model)),
          SliverToBoxAdapter(child: RangeSetting(model: model)),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => MajorCard(
              game: model.game,
              department: rows[i],
              onApply: () => model.apply(context, rows[i]),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 24 * uOf(context))),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Search Majors
// ---------------------------------------------------------------------------

class SearchTab extends StatelessWidget {
  final SubmitModel model;
  const SearchTab({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final rows = model.searched();
        return CustomScrollView(
          key: const PageStorageKey('search-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: SortAndHideRow(model: model)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14 * u, 4 * u, 14 * u, 14 * u),
                child: TextField(
                  key: const ValueKey('major-search'),
                  controller: model.searchController,
                  onChanged: model.setQuery,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 18 * u, color: submitInk),
                  decoration: InputDecoration(
                    hintText: 'Search for your major of choice',
                    hintStyle: TextStyle(
                      fontSize: 16 * u,
                      color: const Color(0xFFC9A58D),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: submitOrange,
                      size: 28 * u,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFFEEDF),
                    contentPadding: EdgeInsets.symmetric(vertical: 12 * u),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16 * u),
                      borderSide: BorderSide(
                        color: submitOrange,
                        width: 2.5 * u,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16 * u),
                      borderSide: BorderSide(
                        color: submitOrange,
                        width: 2.5 * u,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => MajorCard(
                game: model.game,
                department: rows[i],
                onApply: () => model.apply(context, rows[i]),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 24 * u)),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Search within Schools
// ---------------------------------------------------------------------------

class SchoolsTab extends StatelessWidget {
  final SubmitModel model;
  const SchoolsTab({super.key, required this.model});

  static const _skyTop = Color(0xFF4DA6D6);
  static const _skyBottom = Color(0xFFC9E6F0);

  String _label(UniversityCategory c) => switch (c) {
    UniversityCategory.korea =>
      model.game.pack.collegeSet == 'us' ? 'US' : 'Korea',
    UniversityCategory.special => 'Special',
    UniversityCategory.global => 'Global',
    UniversityCategory.taiwan => 'Taiwan',
    UniversityCategory.retake => 'Retake',
  };

  static const _tabs = [
    UniversityCategory.korea,
    UniversityCategory.special,
    UniversityCategory.global,
    UniversityCategory.taiwan,
  ];

  @override
  Widget build(BuildContext context) {
    final u = uOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyBottom],
        ),
      ),
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) {
          final open = model.openSchool;
          if (open != null) return _majors(context, u, open);
          final catalog = model.game.pack.admissions;
          final schools = catalog.inCategory(model.category);
          final tiers = <double, List<University>>{};
          for (final s in schools) {
            (tiers[s.stars] ??= []).add(s);
          }
          return CustomScrollView(
            key: PageStorageKey('schools-scroll-${model.category.name}'),
            slivers: [
              SliverToBoxAdapter(child: _subTabs(u)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(12 * u, 6 * u, 12 * u, 24 * u),
                sliver: SliverList.builder(
                  itemCount: tiers.length,
                  itemBuilder: (context, i) {
                    final stars = tiers.keys.elementAt(i);
                    return _tierPanel(context, u, stars, tiers[stars]!);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _subTabs(double u) => Padding(
    padding: EdgeInsets.fromLTRB(0, 14 * u, 0, 8 * u),
    child: Center(
      child: Container(
        width: 330 * u,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6 * u),
          border: Border.all(color: submitOrange, width: 1.5 * u),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final c in _tabs)
              Expanded(
                child: InkWell(
                  key: ValueKey('schools-${c.name}'),
                  onTap: () => model.setCategory(c),
                  child: Container(
                    height: 34 * u,
                    padding: EdgeInsets.symmetric(horizontal: 4 * u),
                    alignment: Alignment.center,
                    color: c == model.category ? submitOrange : submitCream,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _label(c),
                        style: TextStyle(
                          fontSize: 17 * u,
                          color: c == model.category
                              ? Colors.white
                              : submitOrange,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _tierPanel(
    BuildContext context,
    double u,
    double stars,
    List<University> schools,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        const columns = 3;
        final gap = 10 * u;
        final inner = box.maxWidth - 24 * u;
        final cardWidth = (inner - gap * (columns - 1)) / columns;
        return Container(
          margin: EdgeInsets.only(bottom: 16 * u),
          padding: EdgeInsets.fromLTRB(12 * u, 14 * u, 12 * u, 14 * u),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EA),
            borderRadius: BorderRadius.circular(14 * u),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FFFFFF),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              if (stars > 0) StarRow(stars: stars, size: 30 * u),
              SizedBox(height: 10 * u),
              Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: 14 * u,
                children: [
                  for (final s in schools)
                    SchoolCard(
                      game: model.game,
                      university: s,
                      width: cardWidth,
                      onTap: () => model.openSchoolMajors(s.id),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// RECONSTRUCTED destination (the recording never opens a school): that
  /// school's majors as recommendation-style cards with Apply, under a
  /// header with a back arrow.
  Widget _majors(BuildContext context, double u, int id) {
    final school = model.game.pack.admissions.universities[id];
    final rows = model.majorsOf(id);
    return CustomScrollView(
      key: PageStorageKey('school-majors-$id'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(10 * u, 12 * u, 14 * u, 12 * u),
            child: Row(
              children: [
                PressFeedback(
                  child: IconButton.filled(
                    key: const ValueKey('school-back'),
                    tooltip: 'Back to schools',
                    style: IconButton.styleFrom(backgroundColor: submitOrange),
                    onPressed: () => model.openSchoolMajors(null),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                SizedBox(width: 8 * u),
                Expanded(
                  child: Text(
                    school?.name ?? '',
                    style: TextStyle(
                      fontSize: 22 * u,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Color(0x66000000), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24 * u),
              child: Text(
                'No majors available to apply to here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16 * u, color: Colors.white),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) => MajorCard(
            game: model.game,
            department: rows[i],
            onApply: () => model.apply(context, rows[i]),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 24 * u)),
      ],
    );
  }
}
