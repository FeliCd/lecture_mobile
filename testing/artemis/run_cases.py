"""Run selected ARTEMIS acceptance cases. Keep actual observations for human review."""
import argparse, csv, json, os, pathlib, subprocess, datetime, shutil

p = argparse.ArgumentParser()
p.add_argument('--runs', type=int, default=3)
p.add_argument('--case', default='')
p.add_argument('--artemis-dir', default=os.environ.get('ARTEMIS_HOME', ''))
p.add_argument('--timeout', type=int, default=600)
p.add_argument('--test-class', default='')
args = p.parse_args()
if args.runs < 1 or args.timeout < 1:
    p.error('--runs and --timeout must be positive')
root = pathlib.Path(__file__).resolve().parents[2]
local_artemis = pathlib.Path.home() / '.local/share/artemis-lab3'
artemis = (pathlib.Path(args.artemis_dir) if args.artemis_dir else (
    local_artemis if local_artemis.exists() else pathlib.Path('C:/PRM/tools/artemis'))).resolve()
executable = artemis / '.venv/Scripts/artemis.exe'
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
out = root / 'tmp' / 'artemis-evidence' / stamp
out.mkdir(parents=True)
cases = json.loads((pathlib.Path(__file__).parent/'cases.json').read_text(encoding='utf-8'))
(out/'cases.json').write_text(json.dumps(cases, ensure_ascii=False, indent=2), encoding='utf-8')
selected_cases = {value.strip() for value in args.case.split(',') if value.strip()}
if selected_cases - {case['id'] for case in cases}:
    p.error('Unknown case ID')
key_names = ('GEMINI_API_KEY', 'GOOGLE_API_KEY', 'OPENAI_API_KEY',
             'ANTHROPIC_API_KEY', 'OPEN_ROUTER_API_KEY', 'XAI_API_KEY')
# Inspect presence only. Never print or copy credential values into evidence.
has_key = any(os.environ.get(name, '').strip() for name in key_names)
env_file = artemis / '.env'
adb_settings = {}
if env_file.exists():
    for line in env_file.read_text(encoding='utf-8-sig').splitlines():
        name, sep, value = line.strip().partition('=')
        value = value.strip().strip('"\'')
        if sep and name in key_names and value:
            has_key = True
        if sep and name in ('ADB_HOST', 'ADB_PORT', 'ADB_DEVICE_SERIAL') and value:
            adb_settings[name] = value
blocker = ('ARTEMIS installation is incomplete' if not executable.exists() else
           'Missing model API key in ARTEMIS .env' if not has_key else '')
with (out/'results.csv').open('w', newline='', encoding='utf-8-sig') as f:
    writer = csv.writer(f)
    writer.writerow(['case','run','expected','cli_exit','status','actual','log','screenshot','ui_xml'])
    for case in cases:
        if selected_cases and case['id'] not in selected_cases: continue
        class_label = args.test_class or 'the explicitly selected test class'
        expected = case['expected'].replace('{test_class}', class_label)
        steps = ' '.join(case.get('steps', [])).replace('{test_class}', class_label)
        for run in range(1, args.runs+1):
            log = out/f"{case['id']}-R{run}.log"
            goal = (case['goal'].replace('{test_class}', class_label)+'. Expected: '+expected+
                    '. Steps: '+steps+
                    ('. Explicit test class: '+args.test_class if args.test_class else '') +
                    '. Only use test class/account. Do not log in, grant permissions, send messages, '
                    'confirm crash, save changes or modify attendance. Report BLOCKED if a prerequisite is missing. '
                    'Do not type text, edit any form field or change semester. Do not open import/OCR screens. '
                    'Report observed text and values, never infer PASS from navigation alone.')
            with log.open('w',encoding='utf-8') as stream:
                code, status, actual = '', 'REVIEW_REQUIRED', ''
                if blocker:
                    status, actual = 'NOT_RUN', blocker
                    stream.write('NOT_RUN: '+blocker+'\nNo device test was executed.\n')
                elif case['id'] in ('T06', 'T07') and not args.test_class:
                    status, actual = 'BLOCKED', 'Explicit test class/session not identified'
                    stream.write('BLOCKED: '+actual+'\nNo device test was executed.\n')
                else:
                    try:
                        process = subprocess.Popen([str(executable),'run',goal,
                            '--profile','flash','--locked-app','vn.edu.fpt.lecturer_companion',
                            '--standalone','--test-name',f"LAB3-{case['id']}-R{run}"],cwd=artemis,
                            stdout=stream,stderr=subprocess.STDOUT)
                        code = process.wait(timeout=args.timeout)
                        if code:
                            status, actual = 'RUN_ERROR', 'Review CLI log; no PASS assigned'
                    except subprocess.TimeoutExpired:
                        if os.name == 'nt':
                            subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],
                                stdout=stream,stderr=subprocess.STDOUT,check=False)
                        else:
                            process.kill()
                        process.wait()
                        status, actual = 'TIMEOUT', 'Review log and device state before retry'
                    except OSError as error:
                        status, actual = 'RUN_ERROR', type(error).__name__
            screenshot, ui_xml = '', ''
            adb = shutil.which('adb')
            if adb and status not in ('NOT_RUN', 'BLOCKED'):
                prefix = [adb]
                for name, flag in (('ADB_HOST', '-H'), ('ADB_PORT', '-P'), ('ADB_DEVICE_SERIAL', '-s')):
                    value = os.environ.get(name) or adb_settings.get(name)
                    if value:
                        prefix.extend([flag, value])
                png = out / f"{case['id']}-R{run}.png"
                xml = out / f"{case['id']}-R{run}.xml"
                try:
                    with png.open('wb') as picture:
                        subprocess.run(prefix+['exec-out','screencap','-p'],
                            stdout=picture,stderr=subprocess.DEVNULL,check=True,timeout=20)
                    screenshot = str(png)
                    subprocess.run(prefix+['shell','uiautomator','dump','/sdcard/lab3-verify.xml'],
                        stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=20)
                    with xml.open('wb') as structure:
                        subprocess.run(prefix+['shell','cat','/sdcard/lab3-verify.xml'],
                            stdout=structure,stderr=subprocess.DEVNULL,check=True,timeout=20)
                    ui_xml = str(xml)
                except (subprocess.SubprocessError, OSError):
                    actual = (actual+'; ' if actual else '')+'Evidence capture incomplete'
            writer.writerow([case['id'],run,expected,code,status,actual,str(log),screenshot,ui_xml])
            f.flush()
print(out)
