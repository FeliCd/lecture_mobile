"""Copy recorded ARTEMIS step images/UI trees for independent evidence review."""
import argparse, csv, hashlib, json, pathlib, re, shutil, sqlite3

p = argparse.ArgumentParser()
p.add_argument('results_dir', type=pathlib.Path)
p.add_argument('--artemis-dir', type=pathlib.Path,
               default=pathlib.Path.home()/'.local/share/artemis-lab3')
args = p.parse_args()
artemis = args.artemis_dir.resolve()
db = artemis/'traces/data_engine.db'
connection = sqlite3.connect(db.as_uri()+'?mode=ro', uri=True, timeout=5)
manifest = []
with (args.results_dir/'results.csv').open(encoding='utf-8-sig', newline='') as source:
    rows = list(csv.DictReader(source))
for row in rows:
    if not re.fullmatch(r'T\d{2}', row['case']) or not re.fullmatch(r'[1-9]\d*', row['run']):
        p.error('Unexpected case ID or run number in results.csv')
    raw = pathlib.Path(row['log']).read_text(encoding='utf-8', errors='replace')
    sessions = re.findall(r'Session started: ([0-9a-f-]{36})', raw)
    if not sessions:
        continue
    session = sessions[-1]
    entries = connection.execute(
        'SELECT step_number,pre_image_name,post_image_name,action_taken '
        'FROM steps WHERE session_id=? ORDER BY step_number', (session,)).fetchall()
    target = args.results_dir/'recorded-steps'/f"{row['case']}-R{row['run']}"
    target.mkdir(parents=True, exist_ok=True)
    for number, before, after, action in entries:
        for phase, name in (('before', before), ('after', after)):
            if not name or not re.fullmatch('[0-9a-f]{64}', name):
                continue
            image = artemis/'traces/images'/f'{name}.jpg'
            if not image.exists():
                continue
            destination = target/f'{number:02d}-{phase}.jpg'
            shutil.copyfile(image, destination)
            tree = connection.execute('SELECT ui_tree FROM images WHERE image_name=?',
                                      (name,)).fetchone()
            if tree and tree[0]:
                destination.with_suffix('.json').write_text(tree[0], encoding='utf-8')
            manifest.append({'case': row['case'], 'run': int(row['run']),
                'session_id': session, 'step': number, 'phase': phase,
                'image': str(destination), 'action': json.loads(action) if action else None,
                'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()})
connection.close()
(args.results_dir/'recorded-steps-manifest.json').write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Exported {len(manifest)} recorded step images for review.')
