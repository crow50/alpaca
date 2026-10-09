% Compares Alpaca's configuration merge (configs.pl: checkConfigs/3) with the compatibility
% rule stated in the ACMSE 2019 paper, section 4.1:
%
%   Values (X1,L1) and (X2,L2) are compatible if X1 = X2 = exists,
%   or if X1 = only and L1 U L2 = L1   (and symmetrically when X2 = only).
%
% `paper_ok/4` below is written independently of the code under test.
:- initialization(main, main).
:- consult('/tmp/alpaca/prolog/alpaca').

paper_ok(exists, _,  exists, _).
paper_ok(only,   L1, exists, L2) :- subset(L2, L1).
paper_ok(exists, L1, only,   L2) :- subset(L1, L2).
paper_ok(only,   L1, only,   L2) :- subset(L2, L1).

:- dynamic differs/0.

case(Name, Q1, L1, Q2, L2) :-
    Accepted = [svc-[k-(Q1,L1)]],
    Pending  = [svc-[k-(Q2,L2)]],
    ( paper_ok(Q1,L1,Q2,L2) -> Paper = compatible ; Paper = incompatible ),
    ( catch(checkConfigs(Accepted, Pending, R), _, fail)
    -> Code = compatible, Res = R
    ;  Code = incompatible, Res = '-' ),
    ( Paper == Code -> Verdict = 'agree ' ; Verdict = 'DIFFER', assertz(differs) ),
    format("~w  ~w~t~62|code: ~w~t~83|paper: ~w~t~105|~w~n", [Verdict, Name, Code, Paper, Res]).

main :-
    format("verdict  case (already-accepted requirement  +  this vulnerability's requirement)~n"),
    case('exists [jane,john] + exists [alice]   (paper example)', exists,[jane,john], exists,[alice]),
    case('only [jane] + exists [alice]          (paper example)', only,[jane],        exists,[alice]),
    case('only [a] + only [a]',                                   only,[a],           only,[a]),
    case('only [a] + only [b]',                                   only,[a],           only,[b]),
    case('only [a] + exists [a]',                                 only,[a],           exists,[a]),
    case('only [a,b] + exists [a]    (multi-valued only)',        only,[a,b],         exists,[a]),
    case('only [a,b] + only [a,b]    (same requirement twice)',   only,[a,b],         only,[a,b]),
    case('exists [a] + only [a,b]',                               exists,[a],         only,[a,b]),
    case('exists [a,b] + only [a]',                               exists,[a,b],       only,[a]),
    case('exists [a,b] + only [b]    (same meaning, other order)', exists,[a,b],      only,[b]),
    case('only [] + exists [x]       (empty only-list)',          only,[],            exists,[x]),
    ( differs -> writeln('\nRESULT: code and paper DIFFER on at least one case (see above).')
    ; writeln('\nRESULT: all cases agree with the paper.') ).
