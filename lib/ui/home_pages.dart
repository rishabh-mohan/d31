/// The full pages Home opens: Select Game (MM-26), History (MM-09),
/// Settings, and the collections that are still empty.
///
/// Each is a full page with the original's header (orange title, back
/// chevron, peach rule) over the desk wallpaper under a cream wash, measured
/// on the same 390-wide canvas as Home.
library;

import 'package:flutter/material.dart';

import '../engine/account_store.dart';
import '../engine/content_source.dart';
import '../engine/pack.dart';
import '../engine/record_store.dart';
import '../engine/save_store.dart';
import 'home_screen.dart';
import 'pack_image.dart';

/// Header, washed wallpaper and a body laid out at [u] units per design pixel.
class MenuPage extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context, double u) body;

  /// How strongly the cream wash covers the desk; History's is heavier.
  final double wash;

  const MenuPage({
    super.key,
    required this.title,
    required this.body,
    this.wash = .45,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.paper,
      body: LayoutBuilder(
        builder: (context, box) {
          final u = box.maxWidth / 390;
          return Stack(
            children: [
              const Positioned.fill(
                child: PackImage(
                  path: homeWallpaper,
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: HomeColors.paper.withValues(alpha: wash),
                ),
              ),
              Column(
                children: [
                  _Header(title: title, u: u),
                  Expanded(child: body(context, u)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final double u;
  const _Header({required this.title, required this.u});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeColors.paper,
        border: Border(
          bottom: BorderSide(color: HomeColors.outline, width: 2.2 * u),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F4A2B10),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 62 * u,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 22 * u, color: HomeColors.orange),
              ),
              Positioned(
                left: 4 * u,
                child: IconButton(
                  key: const ValueKey('menu-back'),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: HomeColors.orange,
                    size: 24 * u,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The attached corner block holding a trash icon (red on saves, orange on
/// records), its own hit target apart from the card's.
class _TrashCorner extends StatelessWidget {
  final double u;
  final Color color;
  final double radius;
  final String tooltip;
  final VoidCallback onTap;

  const _TrashCorner({
    super.key,
    required this.u,
    required this.color,
    required this.radius,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.only(
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(10 * u),
    );
    return Material(
      color: color,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40 * u,
            height: 40 * u,
            child: Icon(Icons.delete_outline, color: Colors.white, size: 26 * u),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return yes == true;
}

BoxDecoration _cardDecoration(double u, {Color? border}) => BoxDecoration(
  color: HomeColors.cardFill,
  borderRadius: BorderRadius.circular(10 * u),
  border: Border.all(color: border ?? HomeColors.outline, width: 2 * u),
  boxShadow: [
    BoxShadow(
      color: const Color(0x334A2B10),
      blurRadius: 4 * u,
      offset: Offset(0, 2.5 * u),
    ),
  ],
);

/// MM-26: a new-game tile over one card per unfinished run.
class SelectGamePage extends StatefulWidget {
  final Future<void> Function() onNewGame;
  final Future<void> Function(SaveSummary save) onContinue;

  /// False while the packs are still loading; the plus tile waits.
  final bool ready;

  const SelectGamePage({
    super.key,
    required this.onNewGame,
    required this.onContinue,
    this.ready = true,
  });

  @override
  State<SelectGamePage> createState() => _SelectGamePageState();
}

class _SelectGamePageState extends State<SelectGamePage> {
  List<SaveSummary>? _saves;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final saves = await SaveStore.list();
    if (mounted) setState(() => _saves = saves);
  }

  Future<void> _delete(SaveSummary save) async {
    final name = save.name.isEmpty ? 'this run' : save.name;
    if (!await _confirm(
      context,
      'Delete $name?',
      'The unfinished run is removed for good.',
    )) {
      return;
    }
    await SaveStore.delete(save.slot);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return MenuPage(
      title: 'Select Game',
      wash: .4,
      body: (context, u) {
        final saves = _saves ?? const <SaveSummary>[];
        return ListView(
          padding: EdgeInsets.fromLTRB(25 * u, 30 * u, 25 * u, 30 * u),
          children: [
            _NewGameTile(
              u: u,
              onTap: widget.ready
                  ? () async {
                      await widget.onNewGame();
                      await _refresh();
                    }
                  : null,
            ),
            for (final save in saves) ...[
              SizedBox(height: 19 * u),
              _SaveCard(
                key: ValueKey('save-${save.slot}'),
                u: u,
                save: save,
                onTap: () async {
                  await widget.onContinue(save);
                  await _refresh();
                },
                onDelete: () => _delete(save),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _NewGameTile extends StatelessWidget {
  final double u;
  final VoidCallback? onTap;
  const _NewGameTile({required this.u, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('new-game'),
      height: 114 * u,
      decoration: _cardDecoration(u, border: HomeColors.orange),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10 * u),
          onTap: onTap,
          child: Center(
            child: Container(
              width: 39 * u,
              height: 39 * u,
              decoration: BoxDecoration(
                color: onTap == null ? HomeColors.muted : HomeColors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: HomeColors.paper, size: 32 * u),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveCard extends StatelessWidget {
  final double u;
  final SaveSummary save;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SaveCard({
    super.key,
    required this.u,
    required this.save,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final radius = 10 * u;
    return Container(
      height: 114 * u,
      decoration: _cardDecoration(u),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2 * u),
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ),
            Positioned(
              left: 14 * u,
              top: 16 * u,
              bottom: 0,
              width: 90 * u,
              child: IgnorePointer(
                child: PackImage(
                  path: save.portrait.isEmpty ? null : save.portrait,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            Positioned(
              left: 112 * u,
              right: 30 * u,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'D-${save.daysRemaining}'),
                            TextSpan(text: '  '),
                            TextSpan(
                              text: save.name.isEmpty ? 'Unnamed' : save.name,
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 17 * u,
                          color: HomeColors.ink,
                        ),
                      ),
                    ),
                    SizedBox(height: 4 * u),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        save.modeTitle,
                        style: TextStyle(
                          fontSize: 16 * u,
                          color: const Color(0xFFC0602E),
                        ),
                      ),
                    ),
                    SizedBox(height: 4 * u),
                    Text(
                      '${save.statTotal}',
                      style: TextStyle(
                        fontSize: 12.5 * u,
                        color: HomeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _TrashCorner(
                key: ValueKey('delete-save-${save.slot}'),
                u: u,
                color: HomeColors.trash,
                radius: radius - 2 * u,
                tooltip: 'Delete run',
                onTap: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MM-09: completed runs, two to a row.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<RunRecord>? _records;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final records = await RecordStore.list();
    if (mounted) setState(() => _records = records);
  }

  Future<void> _delete(RunRecord record) async {
    if (!await _confirm(
      context,
      'Delete this record?',
      'The finished run is removed from History for good.',
    )) {
      return;
    }
    await RecordStore.delete(record.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return MenuPage(
      title: 'History',
      wash: .62,
      body: (context, u) {
        final records = _records;
        if (records != null && records.isEmpty) {
          return Center(
            child: Text(
              'No finished runs yet.',
              style: TextStyle(fontSize: 15 * u, color: HomeColors.muted),
            ),
          );
        }
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(36 * u, 22 * u, 36 * u, 30 * u),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 18 * u,
            crossAxisSpacing: 14 * u,
            childAspectRatio: 152 / 253,
          ),
          itemCount: records?.length ?? 0,
          itemBuilder: (context, i) => _RecordCard(
            key: ValueKey('record-${records![i].id}'),
            u: u,
            record: records[i],
            onDelete: () => _delete(records[i]),
          ),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  final double u;
  final RunRecord record;
  final VoidCallback onDelete;

  const _RecordCard({
    super.key,
    required this.u,
    required this.record,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final radius = 13 * u;
    final small = TextStyle(fontSize: 13 * u, color: HomeColors.ink);
    return Container(
      decoration: BoxDecoration(
        color: HomeColors.cardFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: HomeColors.outline, width: 2.5 * u),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 2.5 * u),
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: () => _showDetail(context)),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8 * u, 24 * u, 8 * u, 12 * u),
                  child: Column(
                    children: [
                      Expanded(
                        child: PackImage(
                          path: record.portrait.isEmpty
                              ? null
                              : record.portrait,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      SizedBox(height: 10 * u),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          record.name.isEmpty ? 'Unnamed' : record.name,
                          style: TextStyle(
                            fontSize: 21 * u,
                            color: HomeColors.ink,
                          ),
                        ),
                      ),
                      SizedBox(height: 6 * u),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(record.modeTitle, style: small),
                      ),
                      SizedBox(height: 6 * u),
                      Text(
                        record.ending,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: small,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _TrashCorner(
                key: ValueKey('delete-record-${record.id}'),
                u: u,
                color: const Color(0xFFF4A27A),
                radius: radius - 2.5 * u,
                tooltip: 'Delete record',
                onTap: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What a record opens is not in the captures; this shows what it kept.
  void _showDetail(BuildContext context) {
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.name.isEmpty ? 'Unnamed' : record.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.modeTitle),
              Text(record.ending),
              const SizedBox(height: 12),
              for (final e in record.stats.entries)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(cap(e.key)), Text('${e.value.round()}')],
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text('Total'), Text('${record.statTotal}')],
              ),
              if (record.csatStandardScore case final score?)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CSAT standard score'),
                    Text(score.toStringAsFixed(1)),
                  ],
                ),
              if (record.enrolled case final enrolled?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Enrolled: $enrolled'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// A collection that has no content yet (Achievements stays empty for now).
class EmptyMenuPage extends StatelessWidget {
  final String title;
  final String message;
  const EmptyMenuPage({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => MenuPage(
    title: title,
    wash: .62,
    body: (context, u) => Center(
      child: Text(
        message,
        style: TextStyle(fontSize: 15 * u, color: HomeColors.muted),
      ),
    ),
  );
}

/// The gear. The original's settings inventory was never captured, so this
/// holds the project's own: the university catalog and the packs.
class SettingsPage extends StatefulWidget {
  final List<(ContentPack, PackLocation)> campaigns;
  final Future<void> Function() onReload;

  const SettingsPage({
    super.key,
    required this.campaigns,
    required this.onReload,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _reloading = false;

  Future<void> _setUniversities(UniversitySet value) async {
    setState(() => AccountStore.current.universities = value);
    await AccountStore.save();
  }

  @override
  Widget build(BuildContext context) {
    return MenuPage(
      title: 'Settings',
      wash: .8,
      body: (context, u) {
        final label = TextStyle(fontSize: 16 * u, color: HomeColors.ink);
        final note = TextStyle(fontSize: 12.5 * u, color: HomeColors.muted);
        return ListView(
          padding: EdgeInsets.fromLTRB(25 * u, 24 * u, 25 * u, 30 * u),
          children: [
            Text('Universities', style: label),
            SizedBox(height: 8 * u),
            SegmentedButton<UniversitySet>(
              key: const ValueKey('settings-universities'),
              segments: [
                for (final set in UniversitySet.values)
                  ButtonSegment(value: set, label: Text(set.label)),
              ],
              selected: {AccountStore.current.universities},
              onSelectionChanged: (s) => _setUniversities(s.single),
            ),
            SizedBox(height: 6 * u),
            Text(
              'Which catalog new runs apply to. Global universities stay the '
              'same in both.',
              style: note,
            ),
            SizedBox(height: 28 * u),
            Text('Packs', style: label),
            SizedBox(height: 8 * u),
            for (final (pack, location) in widget.campaigns)
              Container(
                margin: EdgeInsets.only(bottom: 10 * u),
                padding: EdgeInsets.all(12 * u),
                decoration: _cardDecoration(u),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.manifest.name, style: label),
                    SizedBox(height: 4 * u),
                    Text(
                      '${pack.manifest.totalDays} days  ·  '
                      '${pack.locations.length} locations  ·  '
                      '${pack.events.length} events  ·  '
                      '${pack.items.length} items  ·  '
                      '${pack.traits.length} traits',
                      style: note,
                    ),
                    Text(
                      location.editable
                          ? 'Editable pack: ${location.describe}'
                          : location.describe,
                      style: note.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _reloading
                    ? null
                    : () async {
                        setState(() => _reloading = true);
                        await widget.onReload();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reload packs'),
              ),
            ),
          ],
        );
      },
    );
  }
}
