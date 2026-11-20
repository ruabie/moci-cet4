from pathlib import Path
root = Path(__file__).resolve().parents[1]
state = (root / 'scripts/game_state.gd').read_text(encoding='utf-8')
main = (root / 'scripts/main.gd').read_text(encoding='utf-8')
test = (root / 'tests/qa_headless.gd').read_text(encoding='utf-8')
checks = {
 'consumable payment separated from furniture': 'static func spend(state:' in state and 'CitySave.spend(candidate, 18)' in main,
 'isolated engine test writes': 'qa_temp_' in test and 'CitySave.write_save(state, qa_file, qa_backup)' in test,
 'scene QA does not modify live save': 'ProjectSettings.set_setting("application/config/qa_mode", true)' in test and 'if not qa_mode and not CitySave.write_save' in main,
 'state must persist before money commits': 'if not _commit_state(candidate):' in main and 'CitySave.pay_job_once(candidate' in main,
 'apartment state persists': '"at_home": false' in state and 'if in_home:' in main,
}
for name, passed in checks.items():
 print(('PASS' if passed else 'FAIL'), name)
assert all(checks.values()), 'Static regression guard did not pass'
print('PASS: local static regression checks (not engine validation)')