import 'game.dart';
import 'goals.dart';
import 'pack.dart';
import 'state.dart';

/// A draft is independent of a run: browsing never advances the clock.
/// Prototype policy: all catalog setup candidates are owned, without consumption.
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

  bool maleFor(ContentPack pack) =>
      isMale ?? pack.characters[characterId]?.isMale ?? true;

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

  Game commit(ContentPack base) {
    final pack = base.forPlayer(isMale: maleFor(base));
    if (difficulty != 'standard') {
      throw StateError('Elite gameplay rules have not been recovered.');
    }
    if (!pack.characters.containsKey(characterId) ||
        badges.length > 7 ||
        traits.length > 5 ||
        badges.any((id) => !pack.badges.containsKey(id)) ||
        traits.any(
          (id) => pack.traits[id] == null || !eligible(pack.traits[id]!, pack),
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
