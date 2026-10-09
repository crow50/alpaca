#!/usr/bin/env bash
# Runs INSIDE the lab container (see run.sh). The repo is mounted read-only at /repo and every
# check works on a fresh throw-away copy in /tmp/alpaca, so nothing here can modify your checkout.
#
#   checks.sh [all|env|goals|readme|cli|ansible|yaml|merge|api|undefined]

export ANSIBLE_NOCOLOR=1 ANSIBLE_LOCALHOST_WARNING=False \
       ANSIBLE_INVENTORY_UNPARSED_WARNING=False ANSIBLE_DEPRECATION_WARNINGS=False
CHECKS=/checks

h()     { printf '\n==== %s ====\n' "$*"; }
quiet() { grep -v 'Library was moved'; }
fresh() {
    cd / || return
    rm -rf /tmp/alpaca /tmp/ranges && mkdir -p /tmp/alpaca
    tar -C /repo --exclude=.git --exclude=ranges --exclude=review -cf - . | tar -C /tmp/alpaca -xf -
}
generate() {   # same command as README step 1, but run from prolog/ (the only place it works)
    (cd /tmp/alpaca/prolog && swipl main.pl createRangeFromIGS '[]' '[root_shell]' '[paramPasswordLength-5]' \
        >/tmp/generate.log 2>&1)
}

check_env() {
    h "environment"
    swipl --version
    ansible --version | head -1
    dot -V 2>&1
    zip -v | sed -n 2p
    python3 -c 'import yaml; print("PyYAML", yaml.__version__)'
}

check_readme() {
    h "README step 1 run exactly as written (from the repo root)"
    fresh; cd /tmp/alpaca || return
    swipl prolog/main.pl createRangeFromIGS '[]' '[root_shell]' '[paramPasswordLength-5]' >/tmp/readme.log 2>&1
    echo "exit code                       : $?"
    echo "range directory actually used   : $(sed -nE 's#^Writing (.*)/[0-9a-f-]{36}/[0-9a-f-]{36}/playbook.yml#\1#p' /tmp/readme.log | head -1)"
    echo "<repo>/ranges exists?           : $([ -d /tmp/alpaca/ranges ] && echo yes || echo 'NO  (README then says: cd ranges/<id>/<lattice>/)')"
    echo "zip 'name not matched' warnings : $(grep -c 'name not matched' /tmp/readme.log)   (dangling links silently left out of the ZIP)"

    h "same command run from inside prolog/"
    fresh; generate
    echo "range directory actually used   : $(sed -nE 's#^Writing (.*)/[0-9a-f-]{36}/[0-9a-f-]{36}/playbook.yml#\1#p' /tmp/generate.log | head -1)"
    echo "zip 'name not matched' warnings : $(grep -c 'name not matched' /tmp/generate.log)"
    echo "ZIP contents                    : $(unzip -l /tmp/alpaca/ranges/*.zip | tail -1 | awk '{print $2, "entries"}')"
    echo "symlinks are absolute           : $(readlink /tmp/alpaca/ranges/*/*/roles | head -1)   <- only valid on this machine"
}

check_ansible() {
    h "What Ansible actually loads from the generated playbooks (ansible-playbook --list-tasks)"
    fresh; generate
    rid=$(ls /tmp/alpaca/ranges | grep -v '\.zip$' | head -1)
    for lat in $(ls /tmp/alpaca/ranges/"$rid" | grep -v json); do
        cd /tmp/alpaca/ranges/"$rid"/"$lat" || continue
        roles=$(awk '/^  roles:/{f=1;next} f&&/- /{print $2}' playbook.yml)
        tasks=$(ansible-playbook -i localhost, -c local --list-tasks playbook.yml 2>/dev/null)
        echo "lattice ${lat:0:8}:"
        for r in $roles; do
            printf '    role %-9s -> %s task(s) loaded\n' "$r" "$(printf '%s\n' "$tasks" | grep -c "^ *$r : ")"
        done
    done

    h "Dry-run probes on the lattice that contains the web app (needs: php, mysql)"
    web=$(grep -l '^      php:' /tmp/alpaca/ranges/"$rid"/*/playbook.yml | head -1 | xargs dirname)
    cd "$web" || return
    probe() {
        ansible-playbook -i localhost, -c local --check -e ansible_become=false \
            -e ansible_python_interpreter=/usr/bin/python3 --start-at-task "$1" playbook.yml 2>&1
    }
    echo "php deployments requested       : $(awk '/^      php:/{f=1;next} f&&/^        deployments:/{g=1;next} g&&/^          - /{printf "%s ", $2; next} g&&!/^          - /{exit}' playbook.yml)"
    echo "openssh 'Enable root ssh'       : $(probe 'openssh : Enable root ssh' | grep -A1 'TASK \[openssh : Enable root ssh\]' | tail -1)"
    echo "mysql   'Copy my.cnf file'      : $(probe 'mysql : Copy my.cnf file' | grep -m1 'Could not find or access')"
    echo "php     'Copy PHP deployments'  : $(probe 'php : Copy PHP deployments' | grep -m1 'Could not find or access' | cut -c1-120)"
    h "Git's view of the missing template"
    git -c safe.directory=/repo -C /repo check-ignore -v ansible/roles/mysql/templates/my.cnf.j2 \
        || echo "(not ignored)"
    echo "ever committed, anywhere in history? : $(git -c safe.directory=/repo -C /repo log --all --oneline -- 'ansible/roles/mysql/templates/*' | wc -l) commits touch that folder"
}

check_yaml() {
    h "Random passwords written into playbook YAML (real generator + real formatter, parsed by PyYAML)"
    fresh
    for len in 5 8; do
        echo "password length $len, 4000 samples:"
        swipl $CHECKS/yaml_fuzz.pl "$len" 4000 2>/dev/null | python3 $CHECKS/yaml_check.py
    done
    h "How YAML 1.1 types the other values Alpaca writes unquoted"
    python3 - <<'PY'
import yaml
for v in ["Yes", "No", "on", "12345", "0123", "7.6p1", "3.0.3"]:
    r = yaml.safe_load("- " + v)[0]
    print(f"   unquoted {v!r:8} -> {type(r).__name__:5} {r!r}")
PY
}

check_merge() {
    h "Configuration merge (configs.pl) versus the compatibility rule in the ACMSE 2019 paper"
    fresh
    swipl $CHECKS/config_merge.pl 2>&1 | quiet
}

check_api() {
    h "HTTP API (prolog/alpaca_http_api.pl) -- isolated: no network, unprivileged user, throw-away copy"
    fresh
    rm -rf /tmp/apitest && mkdir -p /tmp/apitest && cp -r /tmp/alpaca/prolog /tmp/apitest/prolog
    chown -R 1000:1000 /tmp/apitest
    cd /tmp/apitest/prolog || return
    setpriv --reuid=1000 --regid=1000 --clear-groups env HOME=/tmp swipl alpaca_http_api.pl >/tmp/apitest/server.log 2>&1 &
    for _ in $(seq 1 40); do (echo >/dev/tcp/127.0.0.1/10333) 2>/dev/null && break; sleep 0.5; done

    bound=$(awk 'NR>1 && toupper($2) ~ /:285D$/ && $4=="0A" {print $2}' /proc/net/tcp | head -1)
    case "$bound" in
        00000000:*) echo "listening on                    : 0.0.0.0:10333  (ALL interfaces, no authentication)";;
        0100007F:*) echo "listening on                    : 127.0.0.1:10333 (loopback only)";;
        *)          echo "listening on                    : server did not start -- see log below";;
    esac
    post() { curl -s -m 40 -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:10333/alpaca \
                  -H 'Content-Type: application/json' -d "$1"; }

    # The API parses each argument as a Prolog term, so a filename must itself be a quoted Prolog atom.
    q="'"
    payload() { printf '["graphAllVulns", "%s%s%s"]' "$q" "$1" "$q"; }
    echo "legitimate request              : HTTP $(post "$(payload legit)")  -> $(ls /tmp/apitest/prolog | grep -c '^legit') files written"
    echo "filename = 'x; touch CANARY #'  : HTTP $(post "$(payload 'x; touch CANARY #')")"
    sleep 1
    if find /tmp/apitest -name CANARY | grep -q .; then
        echo "  -> canary file exists: the injected shell command RAN on the server (command injection)"
    else
        echo "  -> canary file not created"
    fi
    echo "filename = '/tmp/apitest/outside' : HTTP $(post "$(payload /tmp/apitest/outside)")"
    [ -e /tmp/apitest/outside.gv ] && echo "  -> file written outside the working directory (path traversal)"
    pkill -f alpaca_http_api 2>/dev/null
    echo; echo "documented start command from the file header ('-g server(10333)'):"
    (cd /tmp/apitest/prolog && timeout 20 setpriv --reuid=1000 --regid=1000 --clear-groups env HOME=/tmp \
        swipl -s alpaca_http_api.pl -g 'server(10333)' 2>&1 | quiet | grep -E 'Started server|Address already in use' | head -2 | cut -c1-150 | sed 's/^/    | /')
}

check_undefined() {
    h "Predicates that are called but never defined (SWI-Prolog's own check:list_undefined)"
    fresh
    swipl -q -g "consult('/tmp/alpaca/prolog/alpaca'), check:list_undefined" -t halt 2>&1 | quiet \
        | sed -E 's#/tmp/alpaca/prolog/##g; s/^Warning: \[Thread main\] ?//' | grep -E '/[0-9]+, which|analysis\.pl'
}

check_cli() {
    h "How the command line behaves when something is wrong (exit code, and how much you are told)"
    fresh; cd /tmp/alpaca/prolog || return
    t() {
        local desc="$1"; shift
        local out rc
        out=$("$@" 2>&1); rc=$?
        printf '%-42s exit=%s   lines printed=%s\n' "$desc" "$rc" "$(printf '%s\n' "$out" | quiet | grep -c .)"
    }
    t "omit paramPasswordLength"           swipl main.pl createRangeFromIGS '[]' '[root_shell]' '[]'
    t "goal that does not exist"           swipl main.pl createRangeFromIGS '[]' '[domain_admin]' '[paramPasswordLength-5]'
    t "typo in the command name"           swipl main.pl createRangFromIGS '[]' '[root_shell]' '[paramPasswordLength-5]'
    t "no arguments at all"                swipl main.pl
    t "malformed list (missing bracket)"   swipl main.pl createRangeFromIGS '[]' '[root_shell' '[paramPasswordLength-5]'
    rm -rf /tmp/alpaca/ranges
    t "start and goal swapped"             swipl main.pl createRangeFromIGS '[root_shell]' '[]' '[paramPasswordLength-5]'
    python3 "$CHECKS/show_generated.py"
    rm -rf /tmp/alpaca/ranges
    dotbin=$(command -v dot)
    mv "$dotbin" "$dotbin.off"
    t "graphviz 'dot' not installed"       swipl main.pl createRangeFromIGS '[]' '[root_shell]' '[paramPasswordLength-5]'
    mv "$dotbin.off" "$dotbin"
    echo "   -> left behind: $(find /tmp/alpaca/ranges -type d | wc -l) folders, $(find /tmp/alpaca/ranges -name playbook.yml | wc -l) playbooks, $(ls /tmp/alpaca/ranges/*.zip 2>/dev/null | wc -l) zips"
}

check_goals() {
    h "Which lattices does each goal produce? (empty start state)"
    fresh
    swipl $CHECKS/goals.pl 2>&1 | quiet
}

case "${1:-all}" in
    env|readme|ansible|yaml|merge|api|undefined|cli|goals) "check_$1" ;;
    all) for c in env goals readme cli ansible yaml merge api undefined; do "check_$c"; done ;;
    *)   echo "usage: checks.sh [all|env|goals|readme|cli|ansible|yaml|merge|api|undefined]"; exit 2 ;;
esac
