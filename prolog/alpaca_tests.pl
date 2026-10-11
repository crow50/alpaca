%run using: swipl -s alpaca_tests.pl -t run_tests

:- [alpaca].
:- prolog_load_context(directory, TestDir), nb_setval(alpaca_test_dir, TestDir).

:- begin_tests(main).

test(graphAllVulns, [nondet]) :-
        graphAllVulns('Testfile').

% Golden lattice-shape tests: from an empty start state, each of these goals should keep
% producing the same number of lattices, with the same number of distinct exploit steps per
% lattice (msort'd, so duplicate counts like ftp's two single-step lattices aren't lost). A
% count that changes is either an intentional vuln-database edit (update the expected value
% here in the same commit) or an unintended planner regression -- this doesn't say which.
lattice_shape(Goal, Lattices) :-
    createAllLatticesFromIGS([], [Goal], Lattices).

step_counts(Lattices, Sorted) :-
    findall(N, ( member((_,Vulns), Lattices),
                 findall(D, member((_,D,_), Vulns), Ds0), sort(Ds0, Ds), length(Ds, N) ),
            Counts0),
    msort(Counts0, Sorted).

test(lattice_shapes) :-
    forall(member(Goal-ExpectedCount-ExpectedSteps, [
        root_shell          -2-[10,17],
        user_shell          -2-[6,12],
        web_admin_access    -1-[6],
        db_access           -1-[3],
        hashed_web_passwords-1-[4],
        web_passwords       -1-[5],
        passwords           -2-[3,12],
        hashed_passwords    -2-[2,12],
        user_list           -1-[2],
        ftp                 -2-[1,1],
        http                -1-[1]
    ]), (
        lattice_shape(Goal, Lattices),
        length(Lattices, ExpectedCount),
        step_counts(Lattices, ExpectedSteps)
    )).

% web_admin_access is the fastest end-to-end exploit path (apache+mysql+php together) --
% pin its exact deployed asset too, not just the step count.
test(web_admin_access_config) :-
    createAllLatticesFromIGS([], [web_admin_access], [(Config,_)|_]),
    memberchk(php-[deployments-(exists,["loginpage1-badsql"])], Config).

% Every file a vuln/4 fact's config says to deploy actually exists under ansible/roles/ --
% this would have caught the php deployment-name mismatch (A3) this round of changes fixed.
% It only covers config-value-driven filenames (deployments/db); a role's own static
% templates/tasks (e.g. mysql's my.cnf.j2) aren't named by any vuln/4 value, so a missing
% one there wouldn't show up here -- that class of bug needs a real Ansible run to catch
% (see review/repro's check_ansible, and docker/provision-and-bake.sh end-to-end).
file_role_key(php, deployments, '.tar.gz').
file_role_key(mysql, db, '.sql.gz').

asset_path(Role, Key, File, Path) :-
    file_role_key(Role, Key, Ext),
    nb_getval(alpaca_test_dir, TestDir),
    atomic_list_concat([TestDir, '/../ansible/roles/', Role, '/files/', File, Ext], Path).

test(deployed_assets_exist) :-
    forall(
        ( vuln(_, _, _, Configs),
          member(Role-RoleConfig, Configs),
          member(Key-(_, Values), RoleConfig),
          member(File, Values),
          asset_path(Role, Key, File, Path)
        ),
        ( exists_file(Path)
        -> true
        ;  format("missing asset: ~w (role ~w, key ~w, file ~w)~n", [Path, Role, Key, File]),
           fail )
    ).

% Configuration merge (configs.pl's checkConfigs/3), pinned to its CURRENT observed behavior.
% This is known to differ from the ACMSE 2019 paper's stated compatibility rule in a few
% multi-valued-"only" cases (see review/repro/config_merge.pl and ALPACA-REVIEW.md's C3) --
% that's a documented discrepancy to revisit deliberately, not something this suite should
% fail on; configs.pl is source of truth here, per AGENTS.md.
merge_case(Q1, L1, Q2, L2, ExpectedCompatible) :-
    Accepted = [svc-[k-(Q1,L1)]],
    Pending  = [svc-[k-(Q2,L2)]],
    ( catch(checkConfigs(Accepted, Pending, _), _, fail)
    -> Actual = compatible
    ;  Actual = incompatible ),
    Actual == ExpectedCompatible.

test(config_merge_rules) :-
    forall(member(Q1-L1-Q2-L2-Expected, [
        exists-[jane,john]-exists-[alice]  -compatible,
        only-[jane]       -exists-[alice]  -incompatible,
        only-[a]          -only-[a]        -compatible,
        only-[a]          -only-[b]        -incompatible,
        only-[a]          -exists-[a]      -compatible,
        only-[a,b]        -exists-[a]      -incompatible,
        only-[a,b]        -only-[a,b]      -incompatible,
        exists-[a]        -only-[a,b]      -incompatible,
        exists-[a,b]      -only-[a]        -incompatible,
        exists-[a,b]      -only-[b]        -compatible,
        only-[]           -exists-[x]      -compatible
    ]), merge_case(Q1, L1, Q2, L2, Expected)).

test(add) :-
        A is 1 + 2,
        A =:= 3.

:- end_tests(main).
