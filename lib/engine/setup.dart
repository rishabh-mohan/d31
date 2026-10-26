import 'account_catalog.dart';
import 'account_store.dart';
import 'game.dart';
import 'goals.dart';
import 'pack.dart';
import 'state.dart';

/// What setup may offer from the player's account (user request,
/// 2026-10-25): university badges the account has unlocked by enrolling
/// there at least once (M05), and traits it holds copies of (packs and
/// combining, M08). Characters are not gated.
///
/// [badges] / [traitCopies] null means unrestricted: the old prototype rule
/// where every catalog badge and eligible trait is offered. Selecting a
/// trait never consumes a copy; whether the original does is unrecovered.
class SetupOwnership {
  final Set<int>? badges;
  final Map<int, int>? traitCopies;

  const SetupOwnership({this.badges, this.traitCopies});

  static const unrestricted = SetupOwnership();

  /// Session override of the account rule (dev panel). Null follows
  /// `setupRequiresOwnership` in content/kss/account-rules.json.
  static bool? debugRequireOwnership;

  bool get restricted => badges != null || traitCopies != null;

  /// The account's ownership, or [unrestricted] when the account rule (or
  /// [debugRequireOwnership]) turns gating off.
  factory SetupOwnership.fromAccount(Account account, AccountCatalog catalog) {
    if (!(debugRequireOwnership ?? catalog.setupRequiresOwnership)) {
      return unrestricted;
    }
    final copies = <int, int>{};
    for (final t in account.traits) {
      copies[t.traitId] = (copies[t.traitId] ?? 0) + 1;
    }
    return SetupOwnership(
      badges: {
        for (final e in account.enrollments.entries)
          if (e.value > 0) e.key,
      },
      traitCopies: copies,
    );
  }

  bool ownsBadge(int universityId) => badges?.contains(universityId) ?? true;

  /// Copies held; 1 for every trait when unrestricted.
  int traitCount(int traitId) =>
      traitCopies == null ? 1 : (traitCopies![traitId] ?? 0);

  bool ownsTrait(int traitId) => traitCount(traitId) > 0;
}

/// A draft is independent of a run: browsing never advances the clock.
/// Badges and traits are limited to [ownership] (unrestricted unless the
/// caller supplies the account's, as Home does); picks are never consumed.
class RunSetup {
  String difficulty = 'standard';
  int? characterId;
  final Set<int> badges = {};
  final Set<int> traits = {};
  String firstName;
  String lastName;

  /// The protagonist's gender where the campaign scripts both (Retry Year).
  /// Null follows the chosen character.
  bool? isMale;

  /// What the badge and trait steps may offer. Home supplies the account's
  /// through [useOwnership].
  SetupOwnership ownership = SetupOwnership.unrestricted;

  bool maleFor(ContentPack pack) =>
      (pack.genderSelection ? isMale : null) ?? recommendedMale(pack);

  /// The selected character's own gender, which setup recommends.
  bool recommendedMale(ContentPack pack) =>
      pack.characters[characterId]?.isMale ?? true;

  RunSetup(ContentPack pack)
    : firstName = pack.manifest.firstName,
      lastName = pack.manifest.lastName {
    characterId = pack.characters.values
        .where((c) => c.isDefault)
        .firstOrNull
        ?.id;
  }

  static bool eligible(GameTrait trait, ContentPack pack) =>
      trait.setupEligible &&
      (trait.storyId == null || trait.storyId == pack.manifest.storyId);

  /// The badges the badge step lists: owned ones in [pack]'s catalog.
  List<UniversityBadge> badgeChoices(ContentPack pack) => [
    for (final b in pack.badges.values)
      if (ownership.ownsBadge(b.universityId)) b,
  ];

  /// The traits the trait step lists: setup-eligible and owned.
  List<GameTrait> traitChoices(ContentPack pack) => [
    for (final t in pack.traits.values)
      if (eligible(t, pack) && ownership.ownsTrait(t.id)) t,
  ];

  /// Adopts [owned] and drops remembered picks it no longer covers or that
  /// [pack] does not have, so a kept draft never blocks Start Game.
  void useOwnership(SetupOwnership owned, ContentPack pack) {
    ownership = owned;
    badges.removeWhere(
      (id) => !pack.badges.containsKey(id) || !owned.ownsBadge(id),
    );
    traits.removeWhere(
      (id) =>
          pack.traits[id] == null ||
          !eligible(pack.traits[id]!, pack) ||
          !owned.ownsTrait(id),
    );
  }

  Game commit(ContentPack base) {
    final pack = base.forPlayer(isMale: maleFor(base));
    if (difficulty != 'standard') {
      throw StateError('Elite gameplay rules have not been recovered.');
    }
    if (!pack.characters.containsKey(characterId) ||
        badges.length > 7 ||
        traits.length > 5 ||
        badges.any(
          (id) => !pack.badges.containsKey(id) || !ownership.ownsBadge(id),
        ) ||
        traits.any(
          (id) =>
              pack.traits[id] == null ||
              !eligible(pack.traits[id]!, pack) ||
              !ownership.ownsTrait(id),
        )) {
      throw StateError('Invalid setup selection');
    }
    final state = GameState.newRun(pack);
    state.difficulty = difficulty;
    state.characterId = characterId;
    state.isMale = maleFor(pack);
    state.badgeIds.addAll(badges);
    state.initialTraitIds.addAll(traits);
    state.firstName = firstName;
    state.lastName = lastName;
    for (final id in traits) {
      state.grantTrait(id);
    }
    state.applyStartingTraitEffects();
    state.hp = state.hpMax;
    state.weeklyGoal = Goals.issue(state);
    return Game(pack: pack, state: state);
  }
}
