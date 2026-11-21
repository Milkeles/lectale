#!/usr/bin/env python3
"""Schema, SQL and OpenAPI smoke tests for optional commerce and owner-approved autograding."""
from pathlib import Path
import copy,json,sqlite3,yaml
from jsonschema import Draft202012Validator,FormatChecker
r=Path(__file__).resolve().parents[1]
schema=json.loads((r/'schemas/course-v3.schema.json').read_text())
v=Draft202012Validator(schema,format_checker=FormatChecker())
base=yaml.safe_load((r/'examples/auto-grading.course.yaml').read_text())
assert v.is_valid(base)
assert base['assignments']
# untrusted course file may not add arbitrary commerce keys
bad=copy.deepcopy(base);bad['pricing']={'price':10};assert not v.is_valid(bad)
# hybrid must always require human release
bad=copy.deepcopy(base);bad['assignments'][0]['grading']['automatic']['releasePolicy']='auto-release';assert not v.is_valid(bad)
# manual mode forbids auto workflow options
bad=copy.deepcopy(base);bad['assignments'][0]['grading']['mode']='manual';assert not v.is_valid(bad)
# automatic requires workflow config
bad=copy.deepcopy(base);bad['assignments'][0]['grading']['automatic']={};assert not v.is_valid(bad)
# invalid workflow paths rejected
bad=copy.deepcopy(base);bad['assignments'][0]['grading']['automatic']['workflowPath']='../../steal.yml';assert not v.is_valid(bad)
# grading-result bounded JSON contract
rv=Draft202012Validator(json.loads((r/'schemas/grading-result-v1.schema.json').read_text()))
valid=json.loads((r/'examples/grading-result.json').read_text());assert rv.is_valid(valid)
bad=copy.deepcopy(valid);bad['score']=10000000;assert not rv.is_valid(bad)
# OpenAPI paths present, valid parse
api=yaml.safe_load((r/'api/openapi.yaml').read_text());assert api['info']['version']=='4.0.0'
for path in ['/courses/{courseId}/checkout','/stripe/webhook','/courses/{courseId}/grading/config']:
 assert path in api['paths']
# SQL migration is SQLite compatible
con=sqlite3.connect(':memory:')
con.executescript((r/'db/0001_init.sql').read_text());con.executescript((r/'db/0002_commerce_autograding.sql').read_text())
tables={x[0] for x in con.execute('SELECT name FROM sqlite_master WHERE type="table"')}
assert {'course_offers','commerce_orders','course_entitlements','grading_jobs','creator_payment_accounts'}.issubset(tables)
print('OK: v3 security/schema regression cases, API inventory and SQLite migration')
