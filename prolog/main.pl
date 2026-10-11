:- initialization main.
:- [alpaca].

/**
 * Run as:  swipl prolog/main.pl <predicateName> <args>
 * 
 * examples:
 *      graphAllVulns 'filename.dot'
 *      createRangeFromIGS '[InitialState]' '[Goal]' '[Params]'
 */

main :-
    current_prolog_flag(argv, Argv),
    parseArgs(Argv),
    halt(0).
main :-
    halt(1).

% Measure performace of predicate
parseArgs([Time|Rest]) :-
    Time = 'time',
    performance(Rest).
% Used for graphAllVulns
parseArgs([Pred, Filename]) :- 
    current_predicate(Pred/1),
    Run =.. [Pred, Filename], 
    call(Run).
% Used for createRangeFromIGS
parseArgs([Pred|Rest]) :-
    argsToTerm(Rest, Initial, Goal, Params),
    current_predicate(Pred/3),
    Run =.. [Pred, Initial, Goal, Params],
    call(Run).

argsToTerm([ArgsInitial, ArgsGoal, ArgsParams], Initial, Goal, Params) :-
    term_to_atom(Initial, ArgsInitial),
    term_to_atom(Goal, ArgsGoal),
    term_to_atom(Params, ArgsParams).

