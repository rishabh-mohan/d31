import 'dart:convert';

import 'package:d30mode/engine/base_content.dart';
import 'package:d30mode/engine/pack.dart';

ContentPack rewardPack({Map<String, dynamic>? rewardChanges}) {
  final reward = <String, dynamic>{
    'enabled': true,
    'itemDraws': 5,
    'fallbackItemId': 101,
    'items': [
      for (var id = 101; id <= 108; id++)
        {
          'id': id,
          'bucket': 'low',
          'gender': id == 102
              ? 'male'
              : id == 103
              ? 'female'
              : 'any',
        },
    ],
    'tiers': {
      for (var i = 0; i < 6; i++)
        'EDCBAS'[i]: {
          'stat': [40, 105, 200, 375, 600, 800][i],
          'items': {'low': 5, 'middle': 0, 'high': 0},
          'traits': [
            {'C': 5},
            {'C': 3, 'B': 2},
            {'B': 5},
            {'B': 3, 'A': 2},
            {'A': 5},
            {},
          ][i],
        },
    },
    ...?rewardChanges,
  };
  final files = <String, dynamic>{
    'pack.json': {
      'id': 'books',
      'name': 'Book test',
      'subjects': ['logic', 'art', 'music', 'language', 'science'],
      'calendar': {
        'startDate': 'DATE_2026100100',
        'endDate': 'DATE_2026110100',
        'ticksPerDay': 15,
      },
      'start': {'locationId': 1},
    },
    'rules.json': {
      'events': {'randomChance': 0},
      'school': {'enabled': false},
    },
    'locations.json': {
      'locations': [
        {
          'id': 1,
          'name': 'Study',
          'actions': [
            {'locationActionType': 'study'},
          ],
        },
      ],
    },
    'events/events.json': {'events': [], 'nodes': []},
    'items.json': {
      'items': [
        for (var id = 101; id <= 108; id++)
          {'id': id, 'name': 'Item $id', 'maxCount': 1},
      ],
    },
    'traits.json': {
      'traits': [
        for (var rank = 0; rank < 3; rank++)
          for (var id = 0; id < 6; id++)
            {
              'id': 200 + rank * 100 + id,
              'name': 'Trait ${200 + rank * 100 + id}',
              'rank': ['C', 'B', 'A'][rank],
              'bookRewardEligible': id < 5,
              'type': 'good',
              'description': 'Study Efficiency +3',
              'effectList': [
                {
                  'type': 'plusStat',
                  'plusStatType': 'detail',
                  'subjectType': 'logic',
                  'storyStat': 3,
                },
              ],
            },
      ],
    },
    'books.json': {
      'books': [
        for (var i = 0; i < 6; i++)
          {
            'id': i + 1,
            'name': 'Book ${'EDCBAS'[i]}',
            'subject': 'logic',
            'power': i + 1,
            'bookRank': '${i + 1}',
            'doneCount': 2,
          },
      ],
    },
    'mechanics.json': {
      'version': 1,
      'hooks': {'bookCompleted': 'BOOK_BONUS', 'traitAcquired': 'TRAIT_BONUS'},
      'callbacks': {
        'BOOK_BONUS': [
          {'op': 'grantItem', 'id': 101},
        ],
        'TRAIT_BONUS': [
          {'op': 'addMoney', 'value': 7},
        ],
      },
    },
  };
  // Rewards come from the base layer, not the pack; load only that table.
  BaseContent.use({'book_rewards.json': jsonEncode(reward)});
  try {
    return ContentPack.fromFiles(files.map((k, v) => MapEntry(k, jsonEncode(v))));
  } finally {
    BaseContent.use({});
  }
}
