"""KSS-specific export adapter; no campaign behavior belongs in the engine."""
import json
from pathlib import Path

def export(out: Path):
    source = Path(__file__).resolve().parents[1] / 'content/kss/mechanics.json'
    mechanics = json.loads(source.read_text(encoding='utf-8'))
    rules = json.loads((out / 'rules.json').read_text(encoding='utf-8'))
    room = rules.get('reflectionRoom', {})
    if 'locationId' in room:
        def call(name, value): return {'op':'call','name':name,'args':[value]}
        ordinary = room.get('ordinaryLocationIds', [])
        mechanics['callbacks']['SET_DOK_BANG'] = [
            {'op':'setSwitch','name':'DOK_BANG_ON','value':{'arg':0}},
            {'op':'if','when':{'eq':[{'arg':0},1]},
             'then':[*[call('LOCK_LOCATION', n) for n in ordinary], call('MOVE_LOCATION',room['locationId']), {'op':'setField','name':'movementLocked','value':True}],
             'else':[call('LOCK_LOCATION',room['locationId']), *[call('UNLOCK_LOCATION',n) for n in ordinary],call('MOVE_LOCATION',room.get('exitLocationId',1000)),{'op':'setField','name':'movementLocked','value':False}]}
        ]
    (out/'mechanics.json').write_text(json.dumps(mechanics,indent=2)+'\n',encoding='utf-8')
