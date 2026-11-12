% =====================================================================
%  REGLAS DE INFERENCIA (LOGICA DE PRIMER ORDEN)
%  Conocimiento que NO esta escrito como hecho, sino que se deduce.
% =====================================================================
:- encoding(utf8).

% --- Comportamiento -------------------------------------------------
% pasivo(X)  <- categoria(X, pasivo)
es_pasivo(X)  :- categoria(X, pasivo).
es_neutral(X) :- categoria(X, neutral).
es_hostil(X)  :- categoria(X, hostil).
es_jefe(X)    :- categoria(X, jefe).

% peligroso(X) <- hostil(X) v jefe(X)
es_peligroso(X) :- es_hostil(X).
es_peligroso(X) :- es_jefe(X).

% inofensivo(X) <- mob(X) ^ no peligroso(X)
es_inofensivo(X) :- es_mob(X), \+ es_peligroso(X).

% --- Crianza y granjas ----------------------------------------------
% criable(X) <- Existe A : alimenta_con(X, A)
se_puede_criar(X) :- es_mob(X), once(alimenta_con(X, _)).

% compite(X,Y) <- Existe A : alimenta_con(X,A) ^ alimenta_con(Y,A) ^ X != Y
compite_alimento(X, Y) :-
    alimenta_con(X, A),
    alimenta_con(Y, A),
    X \= Y.

% util_para_granja(X) <- criable(X) ^ Existe I : produce(X, I)
util_para_granja(X) :- se_puede_criar(X), once(produce(X, _)).

% fuente_de_comida(X) <- Existe I : produce(X, I) ^ comestible(I)
fuente_de_comida(X) :- es_mob(X), once((produce(X, I), es_comestible(I))).

% fuente_de(Item, X): que mob entrega un item (relacion inversa de produce)
fuente_de(Item, X) :- produce(X, Item).

% --- Combate ----------------------------------------------------------
% Los no-muertos reciben mas dano con el encantamiento Castigo (Smite)
% y se curan con pociones de dano.
vulnerable_a_castigo(X)  :- es_no_muerto(X).
se_cura_con_veneno(X)    :- es_no_muerto(X).

% amenaza_nocturna(X) <- peligroso(X) ^ se_quema_al_sol(X)
% (solo son un problema real de noche o en la sombra)
amenaza_nocturna(X) :- es_peligroso(X), se_quema_al_sol(X).

% protector_contra(P, M): P sirve para ahuyentar a M
protector_contra(P, M) :- huye_de(M, P).

% mascota_protectora(P) <- domesticable(P) ^ Existe M : (huye_de(M,P) ^ peligroso(M))
mascota_protectora(P) :-
    es_domesticable(P),
    once((huye_de(M, P), es_peligroso(M))).

% mas_resistente(X,Y) <- vida(X) > vida(Y)
mas_resistente(X, Y) :-
    vida(X, VX), vida(Y, VY), VX > VY.

% mob_mas_resistente(X) <- No existe Y : vida(Y) > vida(X)
mob_mas_resistente(X) :-
    vida(X, V),
    \+ ( vida(_, V2), V2 > V ).

% mob_mas_debil(X) <- No existe Y : vida(Y) < vida(X)
mob_mas_debil(X) :-
    vida(X, V),
    \+ ( vida(_, V2), V2 < V ).

% exclusivo_de(X, D): el mob aparece solo en una dimension
exclusivo_de(X, D) :-
    dimension(X, D),
    \+ ( dimension(X, D2), D2 \= D ).

% corazones(X, C): conversion de puntos de vida a corazones
corazones(X, C) :- vida(X, V), C is V / 2.
