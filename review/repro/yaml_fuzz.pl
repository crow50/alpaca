% Drives Alpaca's REAL generatePassword/2 (configs.pl) and its REAL YAML formatters
% formatVars/2 + formatRoles/2 (output.pl), wrapped in the same template createPlaybook/3 uses,
% and prints N playbooks separated by markers for an external YAML parser (yaml_check.py).
%
%   swipl yaml_fuzz.pl <passwordLength> <count>
:- initialization(main, main).
:- use_module(library(assoc)).
:- consult('/tmp/alpaca/prolog/alpaca').

main :-
    current_prolog_flag(argv, [LenAtom, NAtom|_]),
    atom_number(LenAtom, Len), atom_number(NAtom, N),
    list_to_assoc([paramPasswordLength-Len], Assoc),
    forall(between(1, N, _),
           ( generatePassword(Assoc, P),
             Config = [users-[root-(only,[P])]],
             formatVars(Config, Vars),
             formatRoles(Config, Roles),
             format(atom(S),
                    "---~n- hosts: all~n~t~2|become: true~n~t~2|vars:~n~s~n~t~2|roles:~n~s",
                    [Vars, Roles]),
             format("@@@PW:~w~n~w~n@@@END~n", [P, S]) )).
