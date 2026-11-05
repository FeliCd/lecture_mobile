"""Run selected ARTEMIS acceptance cases. Keep actual observations for human review."""
import argparse, csv, json, os, pathlib, subprocess, datetime

p = argparse.ArgumentParser()
p.add_argument('--runs', type=int, default=3)
p.add_argument('--case', default='')
args = p.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
artemis = pathlib.Path('C:/PRM/tools/artemis')
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
out = root / 'tmp' / 'artemis-evidence' / stamp
out.mkdir(parents=True)
cases = json.loads((pathlib.Path(__file__).parent/'cases.json').read_text(encoding='utf-8'))
with (out/'results.csv').open('w', newline='', encoding='utf-8-sig') as f:
    writer = csv.writer(f)
    writer.writerow(['case','run','expected','cli_exit','status','actual','log'])
    for case in cases:
        if args.case and case['id'] != args.case: continue
        for run in range(1, args.runs+1):
            log = out/f"{case['id']}-R{run}.log"
            goal = (case['goal']+'. Expected: '+case['expected']+
                    '. Only use test class/account. Do not log in, grant permissions, send messages, '
                    'confirm crash, save changes or modify attendance. Report BLOCKED if a prerequisite is missing. '
                    'Report observed text and values, never infer PASS from navigation alone.')
            with log.open('w',encoding='utf-8') as stream:
                result = subprocess.run([str(artemis/'.venv/Scripts/artemis.exe'),'run',goal,
                    '--profile','flash','--locked-app','vn.edu.fpt.lecturer_companion',
                    '--test-name',f"LAB3-{case['id']}-R{run}"],cwd=artemis,stdout=stream,stderr=subprocess.STDOUT)
            writer.writerow([case['id'],run,case['expected'],result.returncode,'REVIEW_REQUIRED','',str(log)])
            f.flush()
print(out)
