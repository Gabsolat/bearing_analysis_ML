:- module(kb, [diagnose/2, kb_summary/1]).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).
:- thread_local obs/2.
:- thread_local setting/2.

/* ===== KNOWLEDGE BASE =====
   Type: standard | literature | assumption  (never measured data; test cases are synthetic) */

% cond(Id, Variable, Operator, Limit, Type, Source)
cond(volt_unbalance, vunb,  >, 1.0,  standard,   'NEMA MG 1-14.36; IEEE 141: keep terminal unbalance below 1%').
cond(cur_unbalance,  iunb,  >, 10.0, literature, 'US DOE Motor Tip Sheet 7: current unbalance is 6-10 times voltage unbalance').
cond(high_thd_i,     thdi,  >, 8.0,  standard,   'IEEE 519 current distortion limit, Isc/IL 20-50 (8%)').
cond(dc_ripple,      vdc,   >, 5.0,  assumption, 'Assumed dc-link ripple alarm level (to be tuned per drive)').
cond(low_pf,         pf,    <, 0.75, assumption, 'Assumed alarm; excepted at light load').
cond(high_slip,      slip,  >, 5.0,  assumption, 'Assumed alarm for NEMA design B at rated load').
cond(high_rise,      rise,  >, 105,  standard,   'Class F temperature rise 105 K (NEMA MG 1 / IEC 60034-1)').
cond(temp_implausible, rise,<, -2,   assumption, 'Winding temperature below ambient is physically impossible').
cond(low_cool,       fan,   <, 0.8,  assumption, 'Coolant flow below 0.8 p.u. of nominal').
cond(high_vib,       vrms,  >, 2.8,  standard,   'ISO 10816-3/20816-3 zone B/C boundary, group 2 rigid').
cond(high_1x,        v1x,   >, 2.0,  literature, '1x running-speed component dominant: unbalance signature').
cond(high_2x,        v2x,   >, 1.0,  literature, '2x running-speed component: misalignment signature').
cond(rotor_sb,       sb,    >, -45,  literature, 'Thomson and Fenger (2001): sideband above -45 dB indicates broken rotor bar').
cond(brg_env,        bpfo,  >, 12,   assumption, 'Envelope amplitude above noise floor at bearing defect frequency (dB)').
cond(brg_hot,        tb,    >, 90,   literature, 'Typical rolling-bearing temperature alarm 85-95 C').
cond(brg_very_hot,   tb,    >, 100,  assumption, 'Severe bearing temperature, lubrication starvation').
cond(low_pi,         pi,    <, 2.0,  standard,   'IEEE 43-2013 minimum polarization index 2.0 (thermal class B and above)').
cond(power_mismatch, res,   >, 5.0,  assumption, 'Residual between metered power and sqrt3 V I PF above 5%').
cond(severe_2x,      r2x,   >, 1.5,  literature, 'NPTEL rotor-fault module: 2x above 150% of 1x indicates severe misalignment at the coupling').
cond(ecc_sb,         ecc,   >, -50,  assumption, 'Eccentricity sidebands at fs +/- m fr are documented in MCSA literature and patents (US 9389276); amplitude limit assumed').
cond(v2fs,           v2fs,  >, 0.7,  assumption, 'Vibration at 2fs rises with static eccentricity (US 9255837); level assumed; excepted under supply unbalance (NREL: 120 Hz vibration)').
cond(gate_asym,      iasym, >, 10,   assumption, 'Open-circuit IGBT makes positive and negative current peaks asymmetric (US 9354276; Tian et al., JPE 2017); limit assumed').
cond(load_osc,       sbl,   >, -50,  assumption, 'Load torque oscillation modulates stator current at fs +/- fosc (ULB ICEM paper); level assumed').
cond(high_axial,     vax,   >, 1.5,  assumption, 'Angular misalignment and coupling faults raise axial vibration (Tractian, NPTEL); level assumed').

% fault(Id, Name)
fault(fn,   'Normal operation').
fault(fsb,  'Stator-winding fault').
fault(fsr,  'Rotor fault (broken bar)').
fault(fbr,  'Bearing fault').
fault(fbb,  'Bearing lubrication fault').
fault(fmi,  'Motor insulation fault').
fault(fum,  'Unbalance or misalignment').
fault(fvfd, 'Drive or power-electronic fault').
fault(fth,  'Thermal or cooling fault').
fault(fi,   'Instrumentation fault').
fault(fig,  'Inverter gating or open-circuit switch fault').
fault(fme,  'Air-gap eccentricity').
fault(fco,  'Coupling or load fault').

% sig(Fault, Condition, Weight): fault signature, weights w_j
sig(fsb,  cur_unbalance, 3).  sig(fsb,  high_rise, 2).
sig(fsr,  rotor_sb, 4).       sig(fsr,  high_slip, 2).  sig(fsr, high_vib, 1).
sig(fbr,  brg_env, 4).        sig(fbr,  brg_hot, 2).    sig(fbr, high_vib, 2).
sig(fbb,  brg_hot, 2).        sig(fbb,  brg_very_hot, 3). sig(fbb, brg_env, 1).
sig(fmi,  low_pi, 4).         sig(fmi,  high_rise, 1).
sig(fum,  high_1x, 3).        sig(fum,  high_2x, 3).    sig(fum, severe_2x, 2). sig(fum, high_vib, 2).
sig(fvfd, dc_ripple, 3).      sig(fvfd, high_thd_i, 3). sig(fvfd, low_pf, 1).
sig(fth,  high_rise, 3).      sig(fth,  low_cool, 4).
sig(fi,   power_mismatch, 4). sig(fi,   temp_implausible, 4).
sig(fig,  gate_asym, 4).      sig(fig,  high_thd_i, 2). sig(fig, cur_unbalance, 1).
sig(fme,  ecc_sb, 4).         sig(fme,  v2fs, 3).
sig(fco,  load_osc, 3).       sig(fco,  high_axial, 3). sig(fco, high_vib, 1).

% necessary(Fault, Condition): fault is refuted if the condition is observed false
necessary(fsr, rotor_sb).  necessary(fmi, low_pi).  necessary(fbr, brg_env).  necessary(fig, gate_asym).  necessary(fme, ecc_sb).

% min_true(Fault, N): minimum number of true signature conditions
min_true(fi, 1) :- !.
min_true(_, 2).

% exceptions (defaults): evidence withdrawn when a better explanation exists
exception(cur_unbalance) :- obs(vunb, U), U > 1.0.
exception(low_pf)        :- obs(load, L), L < 0.4.
exception(high_slip)     :- obs(load, L), L > 1.05.
exception(v2fs)          :- obs(vunb, U), U > 1.0.

% plan(Fault, Action, Priority, Verification)
plan(fsb,  'Megger and surge-test stator; check negative-sequence current; plan rewind if turn-to-turn short confirmed', high, 'Phase currents balanced within 10% and winding resistance balanced after repair').
plan(fsr,  'Run current-signature test at load; inspect rotor bars and end rings; schedule rotor repair or replacement', high, 'Sideband below -45 dB on retest at same load').
plan(fbr,  'Inspect and replace bearing; check shaft currents and fit; review alignment', high, 'Envelope amplitude at defect frequency back to noise floor').
plan(fbb,  'Relubricate with correct grease type and quantity; inspect seals and lubrication interval', medium, 'Bearing temperature below 90 C after 24 h').
plan(fmi,  'Perform insulation resistance and polarization index test; dry out or rewind if PI stays below 2', high, 'PI of at least 2.0 per IEEE 43').
plan(fum,  'Balance rotor and perform laser shaft alignment; check soft foot and coupling', medium, 'Overall vibration below 2.8 mm/s RMS').
plan(fvfd, 'Inspect dc-link capacitors, rectifier and IGBT gate drive; check output filter and carrier settings', high, 'dc ripple below 5% and current THD below 8%').
plan(fth,  'Clean fins and fan, verify fan rotation and ventilation path, check ambient and duty cycle', medium, 'Temperature rise below 105 K at same load').
plan(fi,   'Verify and recalibrate power meter and temperature sensors against a reference before any equipment action', medium, 'Power residual below 5% and temperature above ambient').

plan(fig,  'Inspect gate-drive signals, gate-driver supply and the switching devices of the affected leg; replace the open-circuit device', high, 'Phase-current peak asymmetry below 10% and current THD below 8%').
plan(fme,  'Measure air gap and shaft run-out; check bearing wear, end-shield fits and rotor-stator concentricity; correct fits or replace bearings', high, 'Eccentricity sideband below -50 dB and 2fs vibration below 0.7 mm/s').
plan(fco,  'Inspect coupling element and hubs; check driven-load torque oscillation (blockage, cavitation, gearbox); realign if required', medium, 'Axial vibration below 1.5 mm/s and load-oscillation sideband below -50 dB').

/* ===== SETTINGS: reasoning mode, threshold scale, dropped knowledge groups ===== */
active(F) :- fault(F, _), \+ setting(drop, F).
elimit(L0, L) :- ( setting(scale, S) -> true ; S = 1.0 ), L is L0 + abs(L0)*(S - 1).
uses(ded, [ded]).  uses(ded_abd, [ded, abd]).  uses(ded_cons, [ded, cons]).  uses(full, [ded, abd, cons]).
has(R) :- ( setting(mode, M) -> true ; M = full ), uses(M, L), memberchk(R, L).

/* ===== STATE INTERPRETATION ===== */
derived(rise, R) :- obs(th, T), obs(tamb, A), R is T - A.
derived(res, R)  :- obs(pe, P), obs(vl, V), obs(il, I), obs(pf, F), P > 0,
                    R is 100*abs(P - sqrt(3)*V*I*F/1000)/P.
derived(r2x, R) :- obs(v1x, A), obs(v2x, B), A > 0, R is B/A.
cval(V, X) :- obs(V, X), !.
cval(V, X) :- derived(V, X).

holds(>, V, L) :- V > L.
holds(<, V, L) :- V < L.

cstate(C, S, V) :-
    cond(C, Var, Op, L0, _, _), elimit(L0, L),
    (   cval(Var, V)
    ->  (   holds(Op, V, L)
        ->  (exception(C) -> S = excepted ; S = true)
        ;   S = false )
    ;   S = unknown ).

/* ===== DEDUCTION: KB u E |= F ===== */
fault_eval(F, Conf, NT, Kn, Tot) :-
    findall(W-S, (sig(F, Cn, W), cstate(Cn, S, _)), L),
    aggregate_all(sum(W), member(W-true, L), T),
    aggregate_all(count, member(_-true, L), NT),
    aggregate_all(sum(W), (member(W-S, L), S \== unknown), Kn),
    aggregate_all(sum(W), sig(F, _, W), Tot),
    (Kn > 0 -> Conf is T/Kn ; Conf = 0).

violated(F) :- necessary(F, C), cstate(C, false, _).

deduced(F, Conf) :-
    active(F), F \== fn,
    fault_eval(F, Conf, NT, _, _),
    min_true(F, M), NT >= M, Conf >= 0.6, \+ violated(F).

normal :- \+ cstate(_, true, _).

/* ===== ABDUCTION: minimum-cardinality explanations D u KB |= E ===== */
cand(Fs) :- findall(F, (active(F), F \== fn), Fs).
combo(0, _, []) :- !.
combo(N, [F|Fs], [F|R]) :- N > 0, N1 is N-1, combo(N1, Fs, R).
combo(N, [_|Fs], R)     :- N > 0, combo(N, Fs, R).
covers(Set, Cs) :- forall(member(C, Cs), (member(F, Set), sig(F, C, _))).

abductive([], []) :- !.
abductive(Cs, Sols) :-
    cand(Fs), between(1, 3, N),
    findall(S, (combo(N, Fs, S), covers(S, Cs)), Sols), Sols \== [], !.
abductive(_, []).

set_score(Set, Sc) :-
    findall(C, (member(F, Set), fault_eval(F, C, _, _, _)), Cs),
    sum_list(Cs, Sc).

/* ===== CONSISTENCY-BASED: minimal hitting sets with KB u D u E not |= false ===== */
consistent_set(S) :- \+ (member(F, S), violated(F)).
is_min(All, S) :- \+ (member(T, All), T \== S, subset(T, S)).
min_diag([], []) :- !.
min_diag(Cs, Ds) :-
    cand(Fs),
    findall(S, (between(1, 3, N), combo(N, Fs, S), covers(S, Cs), consistent_set(S)), All),
    include(is_min(All), All, Ds).

/* ===== EXPLANATION AND REPORTING ===== */
evidence(F, E) :-
    sig(F, Cn, W), cstate(Cn, true, V), cond(Cn, Var, Op, L0, Ty, Src), elimit(L0, L),
    atomic_list_concat([F, Cn], '-', R),
    E = _{rule:R, condition:Cn, variable:Var, value:V, op:Op, limit:L, weight:W, type:Ty, source:Src}.

reject_reason(F, 'Necessary condition observed false; hypothesis inconsistent') :- violated(F), !.
reject_reason(F, 'Fewer true conditions than the minimum required') :-
    fault_eval(F, _, NT, _, _), min_true(F, M), NT < M, !.
reject_reason(_, 'Confidence below the 0.6 acceptance threshold').

final_diag(_, [], _, _, [fn], normal) :- !.
final_diag(D, _, _, _, D, deductive) :- D \== [], !.
final_diag([], _, _, [_-S|_], S, consistency) :- !.
final_diag([], _, [_-S|_], _, S, abduction) :- !.
final_diag([], _, _, _, [unresolved], unresolved).

diagnose(In, Out) :-
    statistics(cputime, T0),
    retractall(obs(_, _)), retractall(setting(_, _)),
    forall((get_dict(K, In, V0), number(V0), K \== scale), assertz(obs(K, V0))),
    ( get_dict(scale, In, Sc0), number(Sc0) -> assertz(setting(scale, Sc0)) ; true ),
    ( get_dict(mode, In, M0) -> atom_string(M, M0), assertz(setting(mode, M)) ; true ),
    ( get_dict(drop, In, Dr), is_list(Dr)
    -> forall(member(D0, Dr), (atom_string(D, D0), assertz(setting(drop, D)))) ; true ),
    findall(_{id:C, variable:Var, op:Op, limit:L, value:Val, state:S, type:Ty, source:Src},
            ( cond(C, Var, Op, L1, Ty, Src), elimit(L1, L), cstate(C, S, V1),
              ( var(V1) -> Val = null ; Val = V1 ) ),
            Conds),
    findall(_{id:F, name:N, confidence:Cf, true_count:NT, known_weight:Kn, total_weight:Tot},
            ( active(F), fault(F, N), F \== fn, fault_eval(F, Cf, NT, Kn, Tot) ),
            Faults),
    findall(Cf-F, deduced(F, Cf), Ded0),
    sort(1, @>=, Ded0, Ded),
    pairs_values(Ded, DIds),
    findall(C, cstate(C, true, _), Abn),
    ( has(abd) -> abductive(Abn, AS0) ; AS0 = [] ),
    findall(Sc-S, (member(S, AS0), set_score(S, Sc)), AP), sort(1, @>=, AP, AR),
    findall(_{faults:S, score:Sc}, member(Sc-S, AR), Abd),
    ( has(cons) -> min_diag(Abn, CD) ; CD = [] ),
    findall(Sc2-S2, (member(S2, CD), set_score(S2, Sc2)), CP0), sort(1, @>=, CP0, CP),
    findall(_{faults:S3, score:Sc3}, member(Sc3-S3, CP), Cons),
    final_diag(DIds, Abn, AR, CP, Diag, Basis),
    subtract(Diag, [fn, unresolved], DI),
    findall(_{id:F, evidence:Ev},
            ( member(F, DI), findall(E, evidence(F, E), Ev) ), Expl),
    findall(_{id:F, confidence:Cf, reason:Rs},
            ( active(F), F \== fn, fault_eval(F, Cf, NT, _, _), NT > 0,
              \+ memberchk(F, DI), reject_reason(F, Rs) ),
            Rej),
    findall(_{id:F, action:A, priority:P, verification:Vf},
            ( member(F, DI), plan(F, A, P, Vf) ), Plans),
    ( cval(rise, Rise) -> true ; Rise = null ),
    ( cval(res, Res)   -> true ; Res = null ),
    statistics(cputime, T1), Ms is (T1 - T0)*1000,
    Out = _{diagnosis:Diag, basis:Basis, conditions:Conds, faults:Faults, explanation:Expl,
            rejected:Rej, abductive:Abd, consistency:Cons, plan:Plans,
            derived:_{rise:Rise, residual:Res}, ms:Ms}.

kb_summary(_{faults:Fs, conditions:Cs, signatures:Ss, plans:Ps}) :-
    findall(_{id:F, name:N}, fault(F, N), Fs),
    findall(_{id:C, variable:V, op:O, limit:L, type:T, source:S}, cond(C, V, O, L, T, S), Cs),
    findall(_{fault:F, condition:C, weight:W}, sig(F, C, W), Ss),
    findall(_{fault:F, action:A, priority:P}, plan(F, A, P, _), Ps).
