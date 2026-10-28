/// Home's captured account destinations (TODO 84 M01), specified in
/// docs/ORIGINAL-GAME-FOLLOWUP-2026-10-24.md:
///
///   * [SettingsSheet] F01/F02, with this project's own university and pack
///     settings kept below the captured ones;
///   * [MailBoxSheet] F03/F04;
///   * [ProfileSheet] F05 and its nested [ChangeUsernameDialog] F07;
///   * [ChargingSheet] F08/F09;
///   * [StoreSheet] F10-F16: Ads, Packs, Expansion and Cookie Store tabs.
///
/// This build has no real-money purchases, ads, invitations or mail
/// source: those controls keep their captured layout and answer with
/// [showUnavailable]. Notices and the seasonal Cookie Parade were never
/// captured and are left out, as is Rank.
library;

import 'package:flutter/material.dart';

import '../engine/account_store.dart';
import '../engine/content_source.dart';
import '../engine/pack.dart';
import 'account_widgets.dart';
import 'home_screen.dart';
import 'pack_image.dart';
import 'traits_page.dart';

const _cookieArt = 'kss/images/cookie.png';
const _refreshArt = 'kss/images/reroll.png';

/// The red Close and the failure colour of these dialogs.
const _closeRed = Color(0xFFD45D58);

/// Peach inset panels (balances, Invite Friend, mail rows).
const _inset = Color(0xFFFCEFDD);

/// The notice every purchase, ad and invitation control gives.
const unavailableText = 'Not available in this build.';

void showUnavailable(BuildContext context, [String text = unavailableText]) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
}

/// A transparent Scaffold so notices show above the overlay, not under it.
class _NoticeHost extends StatelessWidget {
  final Widget child;
  const _NoticeHost({required this.child});

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: Colors.transparent, body: child);
}

/// The floating cream dialog of Settings, profile and Charging: thick
/// orange outline, content that scrolls inside it, a fixed red Close.
class HomeModal extends StatelessWidget {
  final Widget Function(BuildContext context, double u) body;

  /// Top-right content that stays put while the body scrolls (Charging's
  /// "Cookies Owned").
  final Widget Function(BuildContext context, double u)? header;

  const HomeModal({super.key, required this.body, this.header});

  @override
  Widget build(BuildContext context) {
    return _NoticeHost(
      child: LayoutBuilder(
        builder: (context, box) {
          final u = box.maxWidth / 390;
          final radius = BorderRadius.circular(12 * u);
          return SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * u,
                  vertical: 24 * u,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: HomeColors.paper,
                    borderRadius: radius,
                    border: Border.all(color: HomeColors.orange, width: 4 * u),
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (header != null) header!(context, u),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                22 * u,
                                header == null ? 24 * u : 8 * u,
                                22 * u,
                                12 * u,
                              ),
                              child: body(context, u),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 10 * u, 0, 24 * u),
                            child: SizedBox(
                              width: 172 * u,
                              child: _FlatButton(
                                key: const ValueKey('modal-close'),
                                u: u,
                                label: 'Close',
                                color: _closeRed,
                                height: 43,
                                onTap: () => Navigator.of(context).pop(),
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
          );
        },
      ),
    );
  }
}

/// A flat rounded action (Close, Copy Code, Q&A, Restore Purchase).
class _FlatButton extends StatelessWidget {
  final double u;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double height;
  final double fontSize;
  final IconData? icon;
  final bool shadow;

  /// After the label (Change's cookie price).
  final Widget? trailing;

  const _FlatButton({
    super.key,
    required this.u,
    required this.label,
    required this.onTap,
    this.color = HomeColors.orange,
    this.height = 40,
    this.fontSize = 17,
    this.icon,
    this.shadow = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8 * u);
    final style = TextStyle(fontSize: fontSize * u, color: Colors.white);
    return Container(
      height: height * u,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: const Color(0x40000000),
                  blurRadius: 4 * u,
                  offset: Offset(0, 2 * u),
                ),
              ]
            : null,
      ),
      child: Material(
        color: color,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * u),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: fontSize * 1.3 * u),
                      SizedBox(width: 6 * u),
                    ],
                    Text(label, style: style),
                    if (trailing != null) ...[
                      SizedBox(width: 8 * u),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final double u;
  const _Divider({required this.u});

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.symmetric(vertical: 16 * u, horizontal: 8 * u),
    height: 1.5 * u,
    color: HomeColors.ink,
  );
}

/// Settings' segmented choices: selected solid orange with cream text,
/// the rest pale peach with brown text (F01/F02). A null handler marks an
/// option this build cannot provide.
class _PeachSegments<T> extends StatelessWidget {
  final double u;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T>? Function(T value) onTap;
  final String keyPrefix;

  const _PeachSegments({
    required this.u,
    required this.options,
    required this.selected,
    required this.onTap,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10 * u);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: 54 * u,
        color: const Color(0xFFFBE8CC),
        child: Row(
          children: [
            for (final e in options.entries)
              Expanded(
                child: Material(
                  color: e.key == selected
                      ? HomeColors.orange
                      : Colors.transparent,
                  child: InkWell(
                    key: ValueKey(
                      '$keyPrefix-${switch (e.key) {
                        final Enum v => v.name,
                        final v => v,
                      }}',
                    ),
                    onTap: () {
                      final handler = onTap(e.key);
                      if (handler == null) {
                        showUnavailable(context);
                      } else {
                        handler(e.key);
                      }
                    },
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6 * u),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 15.5 * u,
                              color: e.key == selected
                                  ? const Color(0xFFFFF7E8)
                                  : HomeColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Settings (F01/F02) ---------------------------------------------------

class SettingsSheet extends StatefulWidget {
  final List<(ContentPack, PackLocation)> campaigns;
  final Future<void> Function() onReload;

  const SettingsSheet({
    super.key,
    required this.campaigns,
    required this.onReload,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _reloading = false;

  Account get _account => AccountStore.current;

  void _update(VoidCallback change) {
    setState(change);
    AccountStore.save();
  }

  @override
  Widget build(BuildContext context) {
    return HomeModal(
      body: (context, u) {
        final heading = TextStyle(fontSize: 21 * u, color: HomeColors.ink);
        final text = TextStyle(fontSize: 13.5 * u, color: HomeColors.ink);
        final note = TextStyle(fontSize: 12 * u, color: HomeColors.muted);
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ToggleSquare(
                  key: const ValueKey('settings-bgm'),
                  u: u,
                  label: 'BGM',
                  icon: Icons.music_note,
                  offIcon: Icons.music_off,
                  on: _account.bgm,
                  onTap: () => _update(() => _account.bgm = !_account.bgm),
                ),
                _ToggleSquare(
                  key: const ValueKey('settings-sfx'),
                  u: u,
                  label: 'SFX',
                  icon: Icons.touch_app,
                  offIcon: Icons.do_not_touch,
                  on: _account.sfx,
                  onTap: () => _update(() => _account.sfx = !_account.sfx),
                ),
                _ToggleSquare(
                  key: const ValueKey('settings-rumble'),
                  u: u,
                  label: 'Rumble',
                  icon: Icons.vibration,
                  offIcon: Icons.mobile_off,
                  on: _account.rumble,
                  onTap: () =>
                      _update(() => _account.rumble = !_account.rumble),
                ),
              ],
            ),
            SizedBox(height: 10 * u),
            Text(
              'Turn your BGM option on\nfor situationally appropriate '
              'background music!',
              textAlign: TextAlign.center,
              style: text,
            ),

            _Divider(u: u),
            Text('Type of Music', style: heading),
            SizedBox(height: 14 * u),
            _PeachSegments<MusicType>(
              u: u,
              keyPrefix: 'settings-music',
              options: {for (final m in MusicType.values) m: m.label},
              selected: _account.music,
              // Orchestral and Carol are paid entitlements here.
              onTap: (m) => m == MusicType.regular
                  ? (v) => _update(() => _account.music = v)
                  : null,
            ),
            SizedBox(height: 14 * u),
            Text(
              "'Orchestra'\nProvided to players with Ad Removal Premium.",
              textAlign: TextAlign.center,
              style: text,
            ),
            SizedBox(height: 6 * u),
            Text(
              "'Carol'\nProvided to players with Endless Winter Deluxe.",
              textAlign: TextAlign.center,
              style: text,
            ),
            _Divider(u: u),
            Text('Language', style: heading),
            SizedBox(height: 14 * u),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * u),
              child: _PeachSegments<String>(
                u: u,
                keyPrefix: 'settings-language',
                options: const {'en': 'English', 'zh_TW': '繁體中文'},
                selected: 'en',
                // Only the English text is imported.
                onTap: (l) => l == 'en' ? (_) {} : null,
              ),
            ),
            ExpansionTile(
              title: Text('Game settings', style: text),
              tilePadding: EdgeInsets.zero,
              children: [
                Text('Universities', style: heading),
                SizedBox(height: 14 * u),
                _PeachSegments<UniversitySet>(
                  u: u,
                  keyPrefix: 'settings-universities',
                  options: {for (final s in UniversitySet.values) s: s.label},
                  selected: _account.universities,
                  onTap: (_) =>
                      (v) => _update(() => _account.universities = v),
                ),
                SizedBox(height: 8 * u),
                Text(
                  'Which catalog new runs apply to. Global universities stay the '
                  'same in both.',
                  textAlign: TextAlign.center,
                  style: note,
                ),
                _Divider(u: u),
                Text('Packs', style: heading),
                SizedBox(height: 10 * u),
                for (final (pack, location) in widget.campaigns)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 8 * u),
                    padding: EdgeInsets.all(10 * u),
                    decoration: BoxDecoration(
                      color: _inset,
                      borderRadius: BorderRadius.circular(10 * u),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.manifest.name,
                          style: text.copyWith(fontSize: 15 * u),
                        ),
                        Text(
                          '${pack.manifest.totalDays} days  ·  '
                          '${pack.locations.length} locations  ·  '
                          '${pack.events.length} events  ·  '
                          '${pack.items.length} items  ·  '
                          '${pack.traits.length} traits',
                          style: note,
                        ),
                        Text(
                          location.describe,
                          style: note.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  key: const ValueKey('settings-reload'),
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
              ],
            ),
          ],
        );
      },
    );
  }
}

/// BGM / SFX / Rumble: label over an orange square icon; off is pale.
class _ToggleSquare extends StatelessWidget {
  final double u;
  final String label;
  final IconData icon;
  final IconData offIcon;
  final bool on;
  final VoidCallback onTap;

  const _ToggleSquare({
    super.key,
    required this.u,
    required this.label,
    required this.icon,
    required this.offIcon,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10 * u);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * u),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.5 * u, color: HomeColors.ink),
          ),
          SizedBox(height: 6 * u),
          Container(
            width: 49 * u,
            height: 49 * u,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x30000000),
                  blurRadius: 3 * u,
                  offset: Offset(0, 2 * u),
                ),
              ],
            ),
            child: Material(
              color: on ? HomeColors.orange : const Color(0xFFD9CFC6),
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: Icon(
                  on ? icon : offIcon,
                  color: Colors.white,
                  size: 28 * u,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Mail Box (F03/F04) ---------------------------------------------------

/// A titled overlay: orange bar, white title and cream X (Mail Box).
class _TitledPanel extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context, double u) body;

  const _TitledPanel({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return _NoticeHost(
      child: LayoutBuilder(
        builder: (context, box) {
          final u = box.maxWidth / 390;
          final radius = BorderRadius.circular(12 * u);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(10 * u, 60 * u, 10 * u, 30 * u),
              child: Container(
                decoration: BoxDecoration(
                  color: HomeColors.paper,
                  borderRadius: radius,
                  border: Border.all(color: HomeColors.orange, width: 4 * u),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 40 * u,
                          color: HomeColors.orange,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 21 * u,
                                  color: Colors.white,
                                ),
                              ),
                              Positioned(
                                right: 4 * u,
                                child: IconButton(
                                  key: const ValueKey('panel-close'),
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.close,
                                    size: 26 * u,
                                    color: const Color(0xFFFFF7E8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: body(context, u)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Equal text tabs with an orange underline under the selected one.
class _UnderlineTabs extends StatelessWidget {
  final double u;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final String keyPrefix;
  final double fontSize;

  const _UnderlineTabs({
    required this.u,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, label) in labels.indexed)
          Expanded(
            child: InkWell(
              key: ValueKey('$keyPrefix-$i'),
              onTap: () => onChanged(i),
              child: Container(
                height: 46 * u,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == selected
                          ? HomeColors.orange
                          : Colors.transparent,
                      width: 2.5 * u,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize * u,
                    height: 1.15,
                    color: i == selected
                        ? HomeColors.ink
                        : HomeColors.ink.withValues(alpha: .8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class MailBoxSheet extends StatefulWidget {
  const MailBoxSheet({super.key});

  @override
  State<MailBoxSheet> createState() => _MailBoxSheetState();
}

class _MailBoxSheetState extends State<MailBoxSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return _TitledPanel(
      title: 'Mail Box',
      body: (context, u) {
        final empty = TextStyle(fontSize: 15 * u, color: HomeColors.muted);
        return Column(
          children: [
            _UnderlineTabs(
              u: u,
              keyPrefix: 'mail-tab',
              labels: const ['Mail List', 'Claimed Mail'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              // No mail source exists: both lists are always empty. The
              // claimed-mail row layout (F04) waits for one.
              child: _tab == 0
                  ? Align(
                      alignment: const Alignment(0, .15),
                      child: Text('Mail Box is empty.', style: empty),
                    )
                  : Column(
                      children: [
                        SizedBox(height: 22 * u),
                        Text(
                          'Shows up to 10 pieces of claimed mail.',
                          style: TextStyle(
                            fontSize: 13.5 * u,
                            fontWeight: FontWeight.bold,
                            color: HomeColors.muted,
                          ),
                        ),
                        const Spacer(),
                        Text('No claimed mail.', style: empty),
                        const Spacer(flex: 2),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---- Profile (F05) and Change Username (F07) ------------------------------

class ProfileSheet extends StatefulWidget {
  final ContentPack? pack;
  const ProfileSheet({super.key, this.pack});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  Account get _account => AccountStore.current;

  Future<void> _rename() async {
    await pushOverlay<void>(context, const ChangeUsernameDialog());
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget sheet) async {
    await pushOverlay<void>(context, sheet);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return HomeModal(
      body: (context, u) {
        final small = TextStyle(fontSize: 12 * u, color: HomeColors.ink);
        final link = TextStyle(fontSize: 13.5 * u, color: HomeColors.ink);
        Widget linkText(String label) => InkWell(
          onTap: () => showUnavailable(context),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 2 * u),
            child: Text(label, style: link),
          ),
        );
        Widget bar() => Text('  |  ', style: link);
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28 * u,
                  backgroundColor: HomeColors.ink,
                  child: Icon(
                    Icons.person,
                    size: 42 * u,
                    color: HomeColors.paper,
                  ),
                ),
                SizedBox(width: 12 * u),
                Flexible(
                  child: Text(
                    _account.username,
                    key: const ValueKey('profile-name'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 22 * u, color: HomeColors.ink),
                  ),
                ),
                SizedBox(width: 6 * u),
                InkWell(
                  key: const ValueKey('profile-rename'),
                  customBorder: const CircleBorder(),
                  onTap: _rename,
                  child: CircleAvatar(
                    radius: 11 * u,
                    backgroundColor: HomeColors.orange,
                    child: Icon(Icons.edit, size: 13 * u, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18 * u),
            Row(
              children: [
                Expanded(
                  child: _BalanceTile(
                    key: const ValueKey('profile-cookies'),
                    u: u,
                    label: 'Cookies',
                    art: _cookieArt,
                    amount: _account.cookies,
                    onPlus: () => _open(const ChargingSheet()),
                  ),
                ),
                SizedBox(width: 14 * u),
                Expanded(
                  child: _BalanceTile(
                    key: const ValueKey('profile-refresh'),
                    u: u,
                    label: 'Refresh Tickets',
                    art: _refreshArt,
                    round: true,
                    amount: _account.refreshTokens,
                    onPlus: () =>
                        _open(StoreSheet(pack: widget.pack, initialTab: 3)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14 * u),
            _InvitePanel(u: u),
            SizedBox(height: 16 * u),
            SizedBox(
              width: 156 * u,
              child: _FlatButton(
                u: u,
                label: 'Q&A',
                icon: Icons.headset_mic_outlined,
                height: 56,
                onTap: () => showUnavailable(context),
              ),
            ),
            SizedBox(height: 10 * u),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                linkText('Copyright'),
                bar(),
                linkText('Terms of Service'),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                linkText('Privacy Policy'),
                bar(),
                linkText('Sign Out'),
                bar(),
                linkText('Delete Account'),
              ],
            ),
            SizedBox(height: 4 * u),
            Text(
              'Account data is kept on this device only.',
              style: small.copyWith(color: HomeColors.muted),
            ),
          ],
        );
      },
    );
  }
}

/// Cookies / Refresh Tickets on the profile: label, icon and number, plus.
class _BalanceTile extends StatelessWidget {
  final double u;
  final String label;
  final String art;
  final bool round;
  final int amount;
  final VoidCallback onPlus;

  const _BalanceTile({
    super.key,
    required this.u,
    required this.label,
    required this.art,
    required this.amount,
    required this.onPlus,
    this.round = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14 * u, horizontal: 6 * u),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(14 * u),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 14.5 * u, color: HomeColors.ink),
            ),
          ),
          SizedBox(height: 12 * u),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24 * u,
                  height: 24 * u,
                  padding: round ? EdgeInsets.all(3 * u) : EdgeInsets.zero,
                  decoration: round
                      ? const BoxDecoration(
                          color: Color(0xFF7A7470),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: PackImage(path: art, fit: BoxFit.contain),
                ),
                SizedBox(width: 8 * u),
                Text(
                  '$amount',
                  style: TextStyle(fontSize: 24 * u, color: HomeColors.ink),
                ),
              ],
            ),
          ),
          SizedBox(height: 12 * u),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onPlus,
            child: CircleAvatar(
              radius: 13 * u,
              backgroundColor: HomeColors.orange,
              child: Icon(Icons.add, size: 20 * u, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invite Friend, shared by the profile and Charging.
class _InvitePanel extends StatelessWidget {
  final double u;
  const _InvitePanel({required this.u});

  @override
  Widget build(BuildContext context) {
    final text = TextStyle(fontSize: 12 * u, color: HomeColors.ink);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12 * u, 14 * u, 12 * u, 12 * u),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(12 * u),
      ),
      child: Column(
        children: [
          Text(
            'Invite Friend',
            style: TextStyle(
              fontSize: 18 * u,
              fontWeight: FontWeight.bold,
              color: HomeColors.ink,
            ),
          ),
          SizedBox(height: 4 * u),
          Text('Receive 10 cookies', style: text.copyWith(fontSize: 14 * u)),
          Text(
            'Rewards will be granted when your friend completes the tutorial.'
            '\n(Up to 10 people)',
            textAlign: TextAlign.center,
            style: text,
          ),
          SizedBox(height: 10 * u),
          Row(
            children: [
              Expanded(
                child: _FlatButton(
                  key: const ValueKey('invite-copy'),
                  u: u,
                  label: 'Copy Code',
                  icon: Icons.copy,
                  height: 34,
                  fontSize: 15,
                  onTap: () => showUnavailable(context),
                ),
              ),
              SizedBox(width: 10 * u),
              Expanded(
                child: _FlatButton(
                  u: u,
                  label: 'View History',
                  icon: Icons.history,
                  height: 34,
                  fontSize: 15,
                  onTap: () => showUnavailable(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// F07: nested over the profile. 2-16 characters, nine cookies.
class ChangeUsernameDialog extends StatefulWidget {
  const ChangeUsernameDialog({super.key});

  @override
  State<ChangeUsernameDialog> createState() => _ChangeUsernameDialogState();
}

class _ChangeUsernameDialogState extends State<ChangeUsernameDialog> {
  late final _field = TextEditingController(
    text: AccountStore.current.username,
  );
  String? _problem;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _change() {
    final account = AccountStore.current;
    final problem = account.renameProblem(_field.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    account.rename(_field.text);
    AccountStore.save();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountStore.current;
    return _NoticeHost(
      child: LayoutBuilder(
        builder: (context, box) {
          final u = box.maxWidth / 390;
          final radius = BorderRadius.circular(12 * u);
          return Center(
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10 * u),
                padding: EdgeInsets.fromLTRB(18 * u, 22 * u, 18 * u, 22 * u),
                decoration: BoxDecoration(
                  color: HomeColors.paper,
                  borderRadius: radius,
                  border: Border.all(color: HomeColors.orange, width: 4 * u),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Change Username ($usernameMinLength-'
                          '$usernameMaxLength characters)',
                          style: TextStyle(
                            fontSize: 18 * u,
                            fontWeight: FontWeight.bold,
                            color: HomeColors.ink,
                          ),
                        ),
                      ),
                      SizedBox(height: 10 * u),
                      TextField(
                        key: const ValueKey('rename-field'),
                        controller: _field,
                        maxLength: usernameMaxLength,
                        style: TextStyle(
                          fontSize: 16 * u,
                          color: HomeColors.ink,
                        ),
                        cursorColor: HomeColors.orange,
                        decoration: InputDecoration(
                          counterText: '',
                          errorText: _problem,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: HomeColors.ink),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: HomeColors.orange,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          if (_problem != null) {
                            setState(() => _problem = null);
                          }
                        },
                        onSubmitted: (_) => _change(),
                      ),
                      SizedBox(height: 8 * u),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 18 * u,
                              child: const PackImage(
                                path: _cookieArt,
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(width: 4 * u),
                            Text(
                              'Cookies Owned : ${account.cookies}',
                              style: TextStyle(
                                fontSize: 14 * u,
                                color: HomeColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16 * u),
                      Row(
                        children: [
                          TextButton(
                            key: const ValueKey('rename-cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15 * u,
                                color: HomeColors.ink,
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 116 * u,
                            child: _FlatButton(
                              key: const ValueKey('rename-change'),
                              u: u,
                              label: 'Change',
                              height: 40,
                              shadow: true,
                              onTap: _change,
                              trailing: CookieAmount(
                                u: u,
                                amount: account.renameCost,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---- Cookie Charging (F08/F09) --------------------------------------------

/// A cookie package as photographed (F08/F14). Real-money prices: shown,
/// never charged.
class CookieOffer {
  final int base;
  final int bonus;
  final int bonusPercent;
  final String price;
  final String art;

  const CookieOffer(
    this.base,
    this.bonus,
    this.bonusPercent,
    this.price,
    this.art,
  );

  int get total => base + bonus;

  static const all = [
    CookieOffer(16, 1, 6, r'$0.99', 'kss/images/cookie_1.png'),
    CookieOffer(32, 4, 12, r'$1.99', 'kss/images/cookie_2.png'),
    CookieOffer(48, 8, 16, r'$2.99', 'kss/images/cookie_3.png'),
    CookieOffer(98, 20, 20, r'$5.99', 'kss/images/cookie_4.png'),
    CookieOffer(298, 75, 25, r'$17.99', 'kss/images/cookie_5.png'),
    CookieOffer(640, 192, 30, r'$38.99', 'kss/images/cookie_6.png'),
    CookieOffer(1280, 448, 35, r'$74.99', 'kss/images/cookie_7.png'),
  ];
}

class _CookiesOwned extends StatelessWidget {
  final double u;
  const _CookiesOwned({required this.u});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      SizedBox.square(
        dimension: 20 * u,
        child: const PackImage(path: _cookieArt, fit: BoxFit.contain),
      ),
      SizedBox(width: 6 * u),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Cookies Owned : ${AccountStore.current.cookies}',
            key: const ValueKey('cookies-owned'),
            style: TextStyle(fontSize: 16 * u, color: HomeColors.ink),
          ),
        ),
      ),
    ],
  );
}

/// The 3/3/1 package grid with red bonus pills over the card tops.
class _OfferGrid extends StatelessWidget {
  final double u;
  const _OfferGrid({required this.u});

  @override
  Widget build(BuildContext context) {
    const offers = CookieOffer.all;
    Widget row(Iterable<CookieOffer> items) => Padding(
      padding: EdgeInsets.only(top: 12 * u),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final o in items)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5 * u),
              child: _OfferCard(u: u, offer: o),
            ),
        ],
      ),
    );
    return Column(
      children: [
        row(offers.take(3)),
        row(offers.skip(3).take(3)),
        row(offers.skip(6)),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  final double u;
  final CookieOffer offer;
  const _OfferCard({required this.u, required this.offer});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(9 * u);
    return SizedBox(
      width: 88 * u,
      height: 104 * u,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 8 * u,
            child: Container(
              decoration: BoxDecoration(
                color: HomeColors.paper,
                borderRadius: radius,
                border: Border.all(color: HomeColors.orange, width: 2 * u),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x30000000),
                    blurRadius: 3 * u,
                    offset: Offset(0, 2 * u),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValueKey('offer-${offer.total}'),
                  borderRadius: radius,
                  onTap: () => showUnavailable(context),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4 * u, 14 * u, 4 * u, 4 * u),
                    child: Column(
                      children: [
                        Expanded(
                          child: PackImage(
                            path: offer.art,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: 3 * u),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${offer.total} ',
                                  style: TextStyle(
                                    fontSize: 13 * u,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: '${offer.base}+${offer.bonus}',
                                  style: TextStyle(
                                    fontSize: 9.5 * u,
                                    color: HomeColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(color: HomeColors.ink),
                          ),
                        ),
                        Text(
                          offer.price,
                          style: TextStyle(
                            fontSize: 13 * u,
                            color: HomeColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -6 * u,
            top: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 6 * u,
                vertical: 1.5 * u,
              ),
              decoration: BoxDecoration(
                color: _closeRed,
                borderRadius: BorderRadius.circular(9 * u),
              ),
              child: Text(
                '${offer.bonusPercent}% BONUS!',
                style: TextStyle(fontSize: 9.5 * u, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChargingSheet extends StatelessWidget {
  const ChargingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeModal(
      header: (context, u) => Padding(
        padding: EdgeInsets.fromLTRB(22 * u, 22 * u, 22 * u, 6 * u),
        child: _CookiesOwned(u: u),
      ),
      body: (context, u) => Column(
        children: [
          Container(
            padding: EdgeInsets.only(bottom: 12 * u),
            decoration: BoxDecoration(
              color: _inset,
              borderRadius: BorderRadius.circular(10 * u),
            ),
            child: _OfferGrid(u: u),
          ),
          SizedBox(height: 14 * u),
          _InvitePanel(u: u),
          SizedBox(height: 14 * u),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(26 * u, 8 * u, 26 * u, 10 * u),
            decoration: BoxDecoration(
              color: _inset,
              borderRadius: BorderRadius.circular(12 * u),
            ),
            child: Column(
              children: [
                _FlatButton(
                  key: const ValueKey('charging-ad'),
                  u: u,
                  label: 'After Ad  Obtain',
                  height: 40,
                  fontSize: 19,
                  shadow: true,
                  onTap: () => showUnavailable(context),
                ),
                SizedBox(height: 8 * u),
                Text(
                  'Up to 2 times daily',
                  style: TextStyle(fontSize: 13 * u, color: HomeColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Store (F10-F16) ------------------------------------------------------

class StoreSheet extends StatefulWidget {
  /// Supplies the trait catalog for the trait-pack shortcut. Without one
  /// the shortcut is disabled.
  final ContentPack? pack;

  /// 0 Ads, 1 Packs, 2 Expansion, 3 Cookie Store.
  final int initialTab;

  const StoreSheet({super.key, this.pack, this.initialTab = 0});

  @override
  State<StoreSheet> createState() => _StoreSheetState();
}

class _StoreSheetState extends State<StoreSheet> {
  late int _tab = widget.initialTab;

  Future<void> _traitPacks() async {
    final pack = widget.pack;
    if (pack == null) return;
    await pushOverlay<void>(context, ManageTraitsSheet(pack: pack));
    AccountStore.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _NoticeHost(
      child: AccountSheet(
        title: 'Store',
        body: (context, u) => Column(
          children: [
            _UnderlineTabs(
              u: u,
              keyPrefix: 'store-tab',
              fontSize: 15.5,
              labels: const ['Ads', 'Packs', 'Expansion', 'Cookie\nStore'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 14 * u, 16 * u, 6 * u),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 112 * u,
                  child: _FlatButton(
                    key: const ValueKey('store-restore'),
                    u: u,
                    label: 'Restore Purchase',
                    height: 30,
                    fontSize: 13,
                    shadow: true,
                    onTap: () => showUnavailable(context),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                key: ValueKey('store-body-$_tab'),
                padding: EdgeInsets.fromLTRB(16 * u, 10 * u, 16 * u, 30 * u),
                children: switch (_tab) {
                  0 => _ads(context, u),
                  1 => _packs(context, u),
                  2 => _expansion(context, u),
                  _ => _cookieStore(context, u),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// F10: the Ad Removal Premium poster and its six merits.
  List<Widget> _ads(BuildContext context, double u) {
    const merits = [
      (Icons.block, 'Ad Removal', '(cookie charging station not included)'),
      (Icons.auto_stories, 'Fund Manager Storyline', null),
      (Icons.style, '「Patron」 Trait', 'Part Time Earnings +400'),
      (Icons.person_outline, 'Hypnotist', 'New Character'),
      (Icons.music_note, 'Orchestra BGM', null),
      (Icons.mail_outline, 'Token of Gratitude', 'New Item'),
    ];
    return [
      _Banner(
        key: const ValueKey('store-premium'),
        u: u,
        colors: const [Color(0xFFF7F4F2), Color(0xFFEDE7E3)],
        border: HomeColors.ink,
        onTap: () => showUnavailable(context),
        child: Column(
          children: [
            Text(
              'support Ad Removal Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22 * u,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFB8325A),
              ),
            ),
            SizedBox(height: 12 * u),
            for (var i = 0; i < merits.length; i += 2)
              Padding(
                padding: EdgeInsets.only(bottom: 10 * u),
                child: Row(
                  children: [
                    for (final (j, m) in merits.skip(i).take(2).indexed) ...[
                      if (j > 0) SizedBox(width: 10 * u),
                      Expanded(
                        child: _MeritCard(
                          u: u,
                          index: i + j + 1,
                          icon: m.$1,
                          title: m.$2,
                          note: m.$3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Text(
              'Thank you for supporting our devs!',
              style: TextStyle(
                fontSize: 15 * u,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5CC08E),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// F11/F12: promotional pack cards. Only the Focus packs' contents and
  /// prices are captured; the others were already owned when photographed.
  List<Widget> _packs(BuildContext context, double u) {
    Widget title(String text, Color color) => Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 26 * u,
        fontWeight: FontWeight.w900,
        color: color,
        shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
      ),
    );
    Widget packRow(int each, int refresh, int cookies) => Wrap(
      alignment: WrapAlignment.center,
      spacing: 6 * u,
      runSpacing: 6 * u,
      children: [
        for (final kind in ['normal', 'jumbo', 'royal', 'ultra'])
          _PackChip(
            u: u,
            art: 'kss/images/trait_pack/$kind.png',
            label: 'X$each',
          ),
        _PackChip(u: u, art: _refreshArt, label: 'X$refresh', round: true),
        _PackChip(u: u, art: _cookieArt, label: 'X$cookies'),
      ],
    );
    return [
      _Banner(
        u: u,
        colors: const [Color(0xFFE0605A), Color(0xFFC94A4A)],
        onTap: () => showUnavailable(context),
        child: Column(
          children: [
            title('[Elite Mode Support Pack]', Colors.white),
            SizedBox(height: 8 * u),
            _Ribbon(u: u, text: 'S-Tier Trait Available'),
          ],
        ),
      ),
      _Banner(
        u: u,
        colors: const [Color(0xFFF8D35E), Color(0xFFF0B43C)],
        onTap: () => showUnavailable(context),
        child: title('Study Starter Pack', HomeColors.ink),
      ),
      _Banner(
        u: u,
        colors: const [Color(0xFF3A52C8), Color(0xFF1C2C80)],
        onTap: () => showUnavailable(context),
        child: Column(
          children: [
            title('Reward X2 Booster', Colors.white),
            SizedBox(height: 6 * u),
            _Ribbon(u: u, text: 'forever X2'),
          ],
        ),
      ),
      _Banner(
        key: const ValueKey('store-focus'),
        u: u,
        colors: const [Color(0xFF9FE3DA), Color(0xFF6CCFC2)],
        price: r'$7.49',
        onTap: () => showUnavailable(context),
        child: Column(
          children: [
            title('Focus Pack', const Color(0xFF3B6B3A)),
            SizedBox(height: 8 * u),
            packRow(1, 54, 50),
          ],
        ),
      ),
      _Banner(
        u: u,
        colors: const [Color(0xFFF7B8A8), Color(0xFFF9E08A)],
        price: r'$14.99',
        onTap: () => showUnavailable(context),
        child: Column(
          children: [
            title('Full Focus Pack', const Color(0xFFE0403A)),
            SizedBox(height: 8 * u),
            packRow(2, 110, 100),
            SizedBox(height: 6 * u),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 26 * u,
                  child: const PackImage(
                    path: 'kss/images/full_focus_package_puzzle_piece.png',
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 6 * u),
                Flexible(
                  child: Text(
                    "The Creator's Thank You Puzzle is included",
                    style: TextStyle(
                      fontSize: 12.5 * u,
                      fontWeight: FontWeight.bold,
                      color: HomeColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  /// F13: the two Deluxe expansions.
  List<Widget> _expansion(BuildContext context, double u) {
    Widget deluxe(String name, List<Color> colors, Color ink) => _Banner(
      u: u,
      colors: colors,
      onTap: () => showUnavailable(context),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30 * u,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: ink, blurRadius: 4)],
            ),
          ),
          Text(
            'Deluxe Edition',
            style: TextStyle(
              fontSize: 15 * u,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
        ],
      ),
    );
    return [
      deluxe('Endless Winter', const [
        Color(0xFFA9BEF5),
        Color(0xFF6C8AE0),
      ], const Color(0xFF2B4A9A)),
      deluxe('Retry Year', const [
        Color(0xFFF4B19A),
        Color(0xFFF7E6E6),
      ], const Color(0xFFD06070)),
    ];
  }

  /// F14-F16: the charging station, then the product shortcuts.
  List<Widget> _cookieStore(BuildContext context, double u) {
    Widget draw(String campaign, List<Color> colors) => _Banner(
      u: u,
      colors: colors,
      shortcut: 'No character draws in this build',
      child: Column(
        children: [
          Text(
            campaign,
            style: TextStyle(fontSize: 16 * u, color: Colors.white),
          ),
          Text(
            'Draw Character',
            style: TextStyle(
              fontSize: 26 * u,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
            ),
          ),
        ],
      ),
    );
    return [
      _GradientBar(u: u, text: 'Cookie Charging Station'),
      SizedBox(height: 12 * u),
      _CookiesOwned(u: u),
      _OfferGrid(u: u),
      SizedBox(height: 28 * u),
      _GradientBar(u: u, text: 'Product'),
      SizedBox(height: 14 * u),
      draw('Max 3-Star Character', const [
        Color(0xFFF2A07A),
        Color(0xFFE76F6F),
      ]),
      draw('Endless Winter', const [Color(0xFFB9CDEB), Color(0xFF8AA5D6)]),
      draw('The Year I Retook', const [Color(0xFFB45BA8), Color(0xFFF08C6C)]),
      // The trait packs exist in the account: their shortcut opens
      // Manage Traits, where they are bought with cookies.
      _Banner(
        key: const ValueKey('store-trait-packs'),
        u: u,
        colors: const [Color(0xFF4F6250), Color(0xFF3B4A3C)],
        border: const Color(0xFF4A2A10),
        shortcut: widget.pack == null ? 'Unavailable' : 'Shortcut>>',
        onTap: widget.pack == null ? null : _traitPacks,
        child: Column(
          children: [
            Text(
              'Road to Acceptance Trait Pack',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24 * u,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFFF7E8),
              ),
            ),
            SizedBox(height: 10 * u),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final kind in ['normal', 'jumbo', 'royal', 'ultra'])
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4 * u),
                    child: SizedBox(
                      width: 48 * u,
                      height: 64 * u,
                      child: PackImage(
                        path: 'kss/images/trait_pack/$kind.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      // No exchange price was captured, and the banner's "rewinds time"
      // is marketing text, not a recovered effect (F16).
      _Banner(
        key: const ValueKey('store-refresh'),
        u: u,
        colors: const [Color(0xFF4F5A48), Color(0xFF3B4436)],
        border: const Color(0xFF4A2A10),
        shortcut: 'Not sold in this build',
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Refresh Ticket that rewinds time',
                style: TextStyle(
                  fontSize: 22 * u,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFF7E8),
                ),
              ),
            ),
            Container(
              width: 70 * u,
              height: 70 * u,
              padding: EdgeInsets.all(12 * u),
              decoration: const BoxDecoration(
                color: Color(0xFFB0A08A),
                shape: BoxShape.circle,
              ),
              child: const PackImage(path: _refreshArt, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
      // Setup already allows five traits, the captured maximum.
      _Banner(
        key: const ValueKey('store-trait-slots'),
        u: u,
        colors: const [Color(0xFFFCEFDD), Color(0xFFFCEFDD)],
        border: HomeColors.ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unleash my full potential!',
              style: TextStyle(
                fontSize: 16 * u,
                fontWeight: FontWeight.bold,
                color: HomeColors.orange,
              ),
            ),
            Text(
              'Trait slot',
              style: TextStyle(
                fontSize: 28 * u,
                fontWeight: FontWeight.w900,
                color: HomeColors.ink,
              ),
            ),
            SizedBox(height: 8 * u),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 5; i++)
                  Container(
                    width: 34 * u,
                    height: 52 * u,
                    decoration: BoxDecoration(
                      color: HomeColors.orange,
                      borderRadius: BorderRadius.circular(17 * u),
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '5/5',
                style: TextStyle(
                  fontSize: 26 * u,
                  fontWeight: FontWeight.w900,
                  color: HomeColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// A large rounded promotional card. [price] adds the white price strip
/// under it (Focus packs); [shortcut] the corner label of product cards.
class _Banner extends StatelessWidget {
  final double u;
  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final Color? border;
  final String? price;
  final String? shortcut;

  const _Banner({
    super.key,
    required this.u,
    required this.colors,
    required this.child,
    this.onTap,
    this.border,
    this.price,
    this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14 * u);
    final body = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14 * u, 16 * u, 14 * u, 16 * u),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shortcut != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                shortcut!,
                style: TextStyle(
                  fontSize: 13 * u,
                  fontWeight: FontWeight.bold,
                  color: onTap == null
                      ? Colors.white.withValues(alpha: .75)
                      : Colors.white,
                ),
              ),
            ),
          child,
        ],
      ),
    );
    return Container(
      margin: EdgeInsets.only(bottom: 18 * u),
      decoration: BoxDecoration(
        color: HomeColors.paper,
        borderRadius: radius,
        border: border == null
            ? null
            : Border.all(color: border!, width: 3 * u),
        boxShadow: [
          BoxShadow(
            color: const Color(0x30000000),
            blurRadius: 5 * u,
            offset: Offset(0, 3 * u),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Column(
              children: [
                body,
                if (price != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8 * u),
                    child: Text(
                      price!,
                      style: TextStyle(
                        fontSize: 20 * u,
                        fontWeight: FontWeight.bold,
                        color: HomeColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeritCard extends StatelessWidget {
  final double u;
  final int index;
  final IconData icon;
  final String title;
  final String? note;

  const _MeritCard({
    required this.u,
    required this.index,
    required this.icon,
    required this.title,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          height: 74 * u,
          margin: EdgeInsets.only(top: 9 * u),
          padding: EdgeInsets.fromLTRB(6 * u, 12 * u, 6 * u, 4 * u),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8 * u),
            boxShadow: [
              BoxShadow(
                color: const Color(0x25000000),
                blurRadius: 3 * u,
                offset: Offset(0, 2 * u),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 26 * u, color: HomeColors.ink),
              SizedBox(width: 4 * u),
              Expanded(
                child: FittedBox(fit: BoxFit.scaleDown, child: _meritText()),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * u, vertical: 2 * u),
          decoration: BoxDecoration(
            color: const Color(0xFFB8325A),
            borderRadius: BorderRadius.circular(8 * u),
          ),
          child: Text(
            'Merit $index',
            style: TextStyle(
              fontSize: 10.5 * u,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// The caption over or under the title, as each merit has it (F10).
  Widget _meritText() => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 110 * u),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note != null && index > 2)
          Text(
            note!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9 * u, color: HomeColors.muted),
          ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5 * u, color: HomeColors.ink),
        ),
        if (note != null && index <= 2)
          Text(
            note!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8 * u, color: HomeColors.muted),
          ),
      ],
    ),
  );
}

class _Ribbon extends StatelessWidget {
  final double u;
  final String text;
  const _Ribbon({required this.u, required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * u, vertical: 4 * u),
      decoration: BoxDecoration(
        color: const Color(0xFFA83A3A),
        borderRadius: BorderRadius.circular(12 * u),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16 * u,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _PackChip extends StatelessWidget {
  final double u;
  final String art;
  final String label;
  final bool round;

  const _PackChip({
    required this.u,
    required this.art,
    required this.label,
    this.round = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 48 * u,
    padding: EdgeInsets.all(4 * u),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(8 * u),
    ),
    child: Column(
      children: [
        Container(
          height: 34 * u,
          padding: round ? EdgeInsets.all(6 * u) : EdgeInsets.zero,
          decoration: round
              ? const BoxDecoration(
                  color: Color(0xFF7A7470),
                  shape: BoxShape.circle,
                )
              : null,
          child: PackImage(path: art, fit: BoxFit.contain),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12 * u,
            fontWeight: FontWeight.w900,
            color: HomeColors.ink,
          ),
        ),
      ],
    ),
  );
}

/// Cookie Store's section bars: red-to-orange gradient, white label.
class _GradientBar extends StatelessWidget {
  final double u;
  final String text;
  const _GradientBar({required this.u, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    height: 34 * u,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFD9636A), HomeColors.orange],
      ),
      borderRadius: BorderRadius.circular(10 * u),
      boxShadow: [
        BoxShadow(
          color: const Color(0x30000000),
          blurRadius: 3 * u,
          offset: Offset(0, 2 * u),
        ),
      ],
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 17 * u, color: Colors.white),
    ),
  );
}
