:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- use_module(kb).

:- http_handler(root(.), http_reply_file('public/index.html', []), []).
:- http_handler(root(api/diagnose), diagnose_h, [method(post)]).
:- http_handler(root(api/kb), kb_h, [method(get)]).

diagnose_h(Request) :-
    http_read_json_dict(Request, In),
    diagnose(In, Out),
    reply_json_dict(Out).

kb_h(_) :- kb_summary(S), reply_json_dict(S).

main :-
    ( getenv('PORT', P0) -> atom_number(P0, Port) ; Port = 8080 ),
    http_server(http_dispatch, [port(Port)]),
    format("Motor-drive expert system listening on port ~w~n", [Port]),
    thread_get_message(_).

:- initialization(main, main).
