% Which lattices does each goal produce from an empty start state, and what does the smallest
% web-only goal (web_admin_access) look like?
:- initialization(main, main).
:- consult('/tmp/alpaca/prolog/alpaca').

main :-
    aggregate_all(count, vuln(_,_,_,_), NV),
    findall(N, vuln(N,[],_,_), Entry),
    format("vulnerabilities in the database : ~w~n", [NV]),
    format("entry points (no prerequisites) : ~w~n~n", [Entry]),
    forall(member(G, [root_shell, user_shell, web_admin_access, db_access, hashed_web_passwords,
                      web_passwords, passwords, hashed_passwords, user_list, ftp, http]),
           ( createAllLatticesFromIGS([], [G], L), L \== []
           -> findall(Nm, ( member((_,V), L), findall(D, member((_,D,_),V), Ds0),
                            sort(Ds0, Ds), length(Ds, Nm) ), Ms),
              length(L, Count),
              format("goal ~w~t~26|~w lattice(s); distinct exploit steps per lattice: ~w~n", [G, Count, Ms])
           ;  format("goal ~w~t~26|(no lattice)~n", [G]) )),
    nl, writeln('--- web_admin_access: the single lattice ---'),
    createAllLatticesFromIGS([], [web_admin_access], [(Cfg,Vs)|_]),
    findall(D, member((_,D,_),Vs), Ds0), sort(Ds0, Ds),
    format("steps : ~w~n", [Ds]),
    format("config: ~w~n", [Cfg]).
