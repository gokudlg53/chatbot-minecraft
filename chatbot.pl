
%  CHATBOT DE MOBS DE MINECRAFT EN PROLOG
%     swipl chatbot.pl          y luego   ?- iniciar_chatbot.

:- encoding(utf8).
:- ensure_loaded(base_conocimiento).
:- ensure_loaded(reglas).

% =====================================================================
% 1. PROCESAMIENTO DE TEXTO
% =====================================================================

% normalizar(+Texto, -Palabras): minusculas, sin tildes, sin signos,
% sin palabras vacias. "¿Qué come el Golem de Hierro?" -> [que,come,golem,hierro]
normalizar(Texto, Palabras) :-
    string_lower(Texto, Min),
    string_chars(Min, Cs0),
    maplist(limpiar_char, Cs0, Cs),
    string_chars(S, Cs),
    split_string(S, " ", " ", Partes0),
    exclude(==(""), Partes0, Partes),
    maplist(atom_string, Atomos, Partes),
    exclude(stopword, Atomos, Palabras).

limpiar_char(C, L) :- tilde(C, L), !.
limpiar_char(C, C) :- char_type(C, alnum), !.
limpiar_char('_', '_') :- !.
limpiar_char(_, ' ').

tilde('á', a). tilde('é', e). tilde('í', i). tilde('ó', o).
tilde('ú', u). tilde('ü', u). tilde('ñ', n).

stopword(W) :- memberchk(W, [de, del, la, el, los, las, un, una, unos, unas,
                            al, a, y, lo, le, les, se, me, en, es, con, por]).

% --- Alias (nombres en ingles o abreviados) --------------------------
alias(zombie, zombi).             alias(skeleton, esqueleto).
alias(spider, arana).             alias(witch, bruja).
alias(husk, zombi_momificado).    alias(stray, esqueleto_glacial).
alias(drowned, ahogado).          alias(pillager, saqueador).
alias(vindicator, vindicador).    alias(evoker, evocador).
alias(ravager, devastador).       alias(silverfish, pececillo).
alias(golem, golem_de_hierro).    alias(dragon, dragon_ender).
alias(cow, vaca).                 alias(pig, cerdo).
alias(sheep, oveja).              alias(chicken, pollo).
alias(wolf, lobo).                alias(bee, abeja).
alias(cat, gato).                 alias(horse, caballo).
alias(villager, aldeano).         alias(magma, cubo_de_magma).

% candidato(Tipo, Atomo, PalabrasDelNombre)
candidato(mob, M, Partes) :-
    es_mob(M), atomic_list_concat(P0, '_', M), exclude(stopword, P0, Partes).
candidato(mob, M, [A]) :- alias(A, M).
candidato(item, I, Partes) :-
    item_conocido(I), atomic_list_concat(P0, '_', I), exclude(stopword, P0, Partes).

item_conocido(I) :- setof(X, M^(produce(M, X) ; alimenta_con(M, X)), Is), member(I, Is).

% entidades_en_frase(+Tipo, +Palabras, -Lista): busca de izquierda a
% derecha, prefiriendo siempre el nombre mas largo ("aldeano zombi"
% gana sobre "aldeano"). Acepta plurales simples (vacas, aranas).
entidades_en_frase(_, [], []).
entidades_en_frase(T, Ws, [E|Es]) :-
    mejor_match(T, Ws, E, Resto), !,
    entidades_en_frase(T, Resto, Es).
entidades_en_frase(T, [_|Ws], Es) :-
    entidades_en_frase(T, Ws, Es).

mejor_match(T, Ws, E, Resto) :-
    findall(N-(X-R),
            ( candidato(T, X, Partes),
            prefijo(Partes, Ws, R),
            length(Partes, N) ),
            L),
    L \= [],
    keysort(L, Ord),
    last(Ord, _-(E-Resto)).

prefijo([], Ws, Ws).
prefijo([P|Ps], [W|Ws], R) :- palabra_igual(P, W), prefijo(Ps, Ws, R).

palabra_igual(P, P) :- !.
palabra_igual(P, W) :- atom_concat(P, s, W), !.
palabra_igual(P, W) :- atom_concat(P, es, W).

% =====================================================================
% 2. UTILIDADES DE SALIDA
% =====================================================================
txt(Atomo, Texto) :-
    atomic_list_concat(Ps, '_', Atomo),
    atomic_list_concat(Ps, ' ', Texto).

lista_txt([], 'ninguno') :- !.
lista_txt(L, Texto) :-
    maplist(txt, L, Ts),
    atomic_list_concat(Ts, ', ', Texto).

resp(Formato, Args) :- format("~n-> "), format(Formato, Args), nl.

leer_linea(Prompt, Linea) :-
    format("~w", [Prompt]), flush_output,
    read_line_to_string(user_input, L),
    (   L == end_of_file -> Linea = "salir" ; Linea = L ).

% leer_mob(-Mob): pide un mob y lo reconoce aunque venga en frase,
% con mayusculas, tildes, plural o en ingles.
leer_mob(Mob) :-
    leer_linea('Nombre del mob: ', L),
    normalizar(L, Ws),
    (   entidades_en_frase(mob, Ws, [Mob|_])
    ->  true
    ;   resp("No reconozco \"~w\" como mob. Usa la opcion 12 para ver la lista.", [L]),
        fail
    ).

leer_item(Item) :-
    leer_linea('Nombre del item: ', L),
    normalizar(L, Ws),
    (   entidades_en_frase(item, Ws, [Item|_])
    ->  true
    ;   resp("No conozco el item \"~w\".", [L]), fail
    ).

% =====================================================================
% 3. RESPUESTAS (cada una usa hechos + reglas)
% =====================================================================
r_alimento(M) :-
    findall(A, alimenta_con(M, A), As),
    (   As \= []
    ->  lista_txt(As, T), txt(M, N),
        resp("El/La ~w se cria/alimenta con: ~w.", [N, T]),
        findall(O, compite_alimento(M, O), Os0), sort(Os0, Os),
        (   Os \= [] -> lista_txt(Os, TO), format("   Comparte alimento con: ~w.~n", [TO]) ; true )
    ;   txt(M, N), resp("El/La ~w no se puede criar con comida (no hay alimento registrado).", [N])
    ).

r_produce(M) :-
    txt(M, N),
    findall(I, produce(M, I), Is),
    (   Is \= []
    ->  lista_txt(Is, T), resp("El/La ~w suelta/produce: ~w.", [N, T]),
        (   fuente_de_comida(M) -> format("   Es una fuente de comida.~n") ; true )
    ;   resp("El/La ~w no suelta items relevantes.", [N])
    ).

r_comportamiento(M) :-
    txt(M, N), categoria(M, C),
    descripcion_categoria(C, D),
    resp("El/La ~w es ~w (~w).", [N, C, D]),
    (   amenaza_nocturna(M) -> format("   Se quema con el sol: es peligroso principalmente de noche.~n") ; true ).

descripcion_categoria(pasivo,  'nunca ataca al jugador').
descripcion_categoria(neutral, 'ataca solo si lo provocas').
descripcion_categoria(hostil,  'ataca al jugador apenas lo ve').
descripcion_categoria(jefe,    'enemigo de alto nivel, muy peligroso').

r_vida(M) :-
    txt(M, N), vida(M, V), corazones(M, C),
    resp("El/La ~w tiene ~w puntos de vida (~w corazones).", [N, V, C]).

r_dimension(M) :-
    txt(M, N), findall(D, dimension(M, D), Ds), lista_txt(Ds, T),
    resp("El/La ~w aparece en: ~w.", [N, T]),
    (   exclusivo_de(M, D) -> format("   Es exclusivo del ~w.~n", [D]) ; true ).

r_domesticable(M) :-
    txt(M, N),
    (   es_domesticable(M) -> resp("Sí, el/la ~w es domesticable.", [N])
    ;   resp("No, el/la ~w no es domesticable.", [N]) ),
    (   es_montable(M) -> format("   Además se puede montar.~n") ; true ),
    (   mascota_protectora(M) ->
        findall(X, protector_contra(M, X), Xs), lista_txt(Xs, TX),
        format("   Sirve como protección: ahuyenta a ~w.~n", [TX]) ; true ).

r_huye(M) :-
    txt(M, N),
    findall(P, huye_de(M, P), Ps),
    findall(X, protector_contra(M, X), Xs),
    (   Ps \= [] -> lista_txt(Ps, TP), resp("El/La ~w huye de: ~w.", [N, TP]) ; true ),
    (   Xs \= [] -> lista_txt(Xs, TX), resp("El/La ~w ahuyenta a: ~w.", [N, TX]) ; true ),
    (   Ps == [], Xs == [] -> resp("No tengo registrado que el/la ~w huya de algo o ahuyente a otro mob.", [N]) ; true ).

r_huye_par(A, B) :-
    txt(A, NA), txt(B, NB),
    (   huye_de(A, B) -> resp("Sí, el/la ~w huye del/de la ~w.", [NA, NB])
    ;   huye_de(B, A) -> resp("Al revés: el/la ~w huye del/de la ~w.", [NB, NA])
    ;   resp("No hay relación de huida registrada entre ~w y ~w.", [NA, NB]) ).

r_sol(M) :-
    txt(M, N),
    (   se_quema_al_sol(M) -> resp("Sí, el/la ~w se quema con la luz del sol.", [N])
    ;   resp("No, el/la ~w no se quema con el sol.", [N]) ).

r_no_muerto(M) :-
    txt(M, N),
    (   es_no_muerto(M)
    ->  resp("Sí, el/la ~w es no-muerto: recibe más daño con Castigo (Smite) y la poción de daño lo cura.", [N])
    ;   resp("No, el/la ~w no es no-muerto.", [N]) ).

r_vuela(M) :-
    txt(M, N),
    (   vuela(M) -> resp("Sí, el/la ~w puede volar.", [N]) ; resp("No, el/la ~w no vuela.", [N]) ).

r_agua(M) :-
    txt(M, N),
    (   es_acuatico(M)    -> resp("El/La ~w es acuático, vive en el agua.", [N])
    ;   danado_por_agua(M) -> resp("El/La ~w recibe daño con el agua.", [N])
    ;   resp("El/La ~w no es acuático ni le afecta el agua.", [N]) ).

r_compite(A, B) :-
    txt(A, NA), txt(B, NB),
    findall(F, (alimenta_con(A, F), alimenta_con(B, F)), Fs0), sort(Fs0, Fs),
    (   Fs \= [] -> lista_txt(Fs, T), resp("Sí, ~w y ~w comparten alimento: ~w.", [NA, NB, T])
    ;   resp("No, ~w y ~w no comparten alimento.", [NA, NB]) ).

r_comparar(A, B) :-
    txt(A, NA), txt(B, NB), vida(A, VA), vida(B, VB),
    (   mas_resistente(A, B) -> resp("El/La ~w (~w pv) es más resistente que el/la ~w (~w pv).", [NA, VA, NB, VB])
    ;   mas_resistente(B, A) -> resp("El/La ~w (~w pv) es más resistente que el/la ~w (~w pv).", [NB, VB, NA, VA])
    ;   resp("~w y ~w tienen la misma vida (~w pv).", [NA, NB, VA]) ).

r_quien_suelta(I) :-
    txt(I, NI), findall(M, fuente_de(I, M), Ms0), sort(Ms0, Ms),
    (   Ms \= [] -> lista_txt(Ms, T), resp("~w se obtiene de: ~w.", [NI, T])
    ;   resp("Ningún mob suelta ~w.", [NI]) ),
    findall(M2, alimenta_con(M2, I), Cs0), sort(Cs0, Cs),
    (   Cs \= [] -> lista_txt(Cs, TC), format("   Además sirve para criar a: ~w.~n", [TC]) ; true ).

r_categoria(C) :-
    findall(M, categoria(M, C), Ms), length(Ms, N), lista_txt(Ms, T),
    resp("Mobs ~w (~w): ~w.", [C, N, T]).

r_todos :-
    findall(M, es_mob(M), Ms), length(Ms, N),
    resp("Hay ~w mobs registrados:", [N]),
    forall(member(C, [pasivo, neutral, hostil, jefe]),
        ( findall(M, categoria(M, C), L), lista_txt(L, T),
        format("   [~w] ~w~n", [C, T]) )).

r_extremo(mas) :-
    mob_mas_resistente(M), txt(M, N), vida(M, V),
    resp("El mob más resistente es el/la ~w con ~w puntos de vida.", [N, V]).
r_extremo(menos) :-
    findall(N, (mob_mas_debil(M), txt(M, N)), Ns), atomic_list_concat(Ns, ', ', T),
    once(mob_mas_debil(M0)), vida(M0, V),
    resp("El mob con menos vida es: ~w (~w puntos de vida).", [T, V]).

% Ficha completa: junta todo lo que se sabe e infiere de un mob
r_ficha(M) :-
    txt(M, N), categoria(M, C), vida(M, V), corazones(M, Co),
    findall(D, dimension(M, D), Ds), lista_txt(Ds, TD),
    findall(A, alimenta_con(M, A), As), lista_txt(As, TA),
    findall(I, produce(M, I), Is), lista_txt(Is, TI),
    findall(R, rasgo(M, R), Rs), lista_txt(Rs, TR),
    format("~n===== FICHA: ~w =====~n", [N]),
    format("  Categoría : ~w~n", [C]),
    format("  Vida      : ~w pv (~w corazones)~n", [V, Co]),
    format("  Dimensión : ~w~n", [TD]),
    format("  Se cría con: ~w~n", [TA]),
    format("  Suelta    : ~w~n", [TI]),
    format("  Rasgos    : ~w~n", [TR]).

rasgo(M, domesticable)          :- es_domesticable(M).
rasgo(M, montable)              :- es_montable(M).
rasgo(M, no_muerto)             :- es_no_muerto(M).
rasgo(M, se_quema_al_sol)       :- se_quema_al_sol(M).
rasgo(M, vuela)                 :- vuela(M).
rasgo(M, acuatico)              :- es_acuatico(M).
rasgo(M, danado_por_agua)       :- danado_por_agua(M).
rasgo(M, ataca_a_distancia)     :- ataca_a_distancia(M).
rasgo(M, explota)               :- explota(M).
rasgo(M, participa_en_asaltos)  :- participa_en_asalto(M).
rasgo(M, util_para_granja)      :- util_para_granja(M).
rasgo(M, amenaza_nocturna)      :- amenaza_nocturna(M).

% =====================================================================
% 4. PREGUNTAS EN LENGUAJE NATURAL
% =====================================================================
% intencion(+Palabras, -Intencion): primera intencion cuyas palabras clave
% aparezcan en la frase (el orden de las clausulas es la prioridad).
intencion(Ws, I) :- clave(I, Claves), member(W, Ws), memberchk(W, Claves), !.
intencion(_, ficha).

clave(compite,   [compite, compiten, comparten, comparte]).
clave(huye,      [teme, temen, huye, huyen, miedo, asusta, asustan, ahuyenta,
                ahuyentar, espanta, espantar, protege, proteger]).
clave(alimento,  [come, comen, comer, alimenta, alimentan, alimentar, alimento,
                criar, cria, crian, reproducir, reproduce, aparear]).
clave(produce,   [suelta, sueltan, soltar, dropea, drop, drops, produce, producen,
                da, dan, obtener, obtiene, obtengo, consigo, conseguir, saca, sacar]).
clave(comparar,  [comparar, compara, vs, versus]).
clave(vida,      [vida, corazones, corazon, resistente, aguanta, salud, fuerte, debil]).
clave(dimension, [donde, dimension, aparece, aparecen, vive, viven, encuentra,
                encuentro, spawnea]).
clave(domestica, [domesticar, domesticable, domestica, mascota, domar, montar, montable]).
clave(sol,       [sol, quema, queman, quemar]).
clave(no_muerto, [muerto, undead, castigo, smite]).
clave(vuela,     [vuela, vuelan, volar, volador]).
clave(agua,      [agua, nada, nadar, acuatico]).
clave(tipo,      [peligroso, peligrosa, ataca, atacan, hostil, pasivo, neutral,
                agresivo, tipo, jefe]).
clave(lista,     [lista, listar, todos, cuantos, mobs, hostiles, pasivos,
                neutrales, jefes]).

responder_frase(Texto) :-
    normalizar(Texto, Ws),
    entidades_en_frase(mob, Ws, Mobs),
    intencion(Ws, I),
    (   responder(I, Mobs, Ws) -> true
    ;   no_entendi ).

% --- Dos mobs ---
responder(compite,  [A, B|_], _) :- !, r_compite(A, B).
responder(huye,     [A, B|_], _) :- !, r_huye_par(A, B).
responder(comparar, [A, B|_], _) :- !, r_comparar(A, B).
responder(vida,     [A, B|_], _) :- !, r_comparar(A, B).
% --- Un mob ---
responder(compite,   [M|_], _) :- !, r_alimento(M).
responder(huye,      [M|_], _) :- !, r_huye(M).
responder(alimento,  [M|_], _) :- !, r_alimento(M).
responder(produce,   [M|_], _) :- !, r_produce(M).
responder(vida,      [M|_], _) :- !, r_vida(M).
responder(comparar,  [M|_], _) :- !, r_vida(M).
responder(dimension, [M|_], _) :- !, r_dimension(M).
responder(domestica, [M|_], _) :- !, r_domesticable(M).
responder(sol,       [M|_], _) :- !, r_sol(M).
responder(no_muerto, [M|_], _) :- !, r_no_muerto(M).
responder(vuela,     [M|_], _) :- !, r_vuela(M).
responder(agua,      [M|_], _) :- !, r_agua(M).
responder(tipo,      [M|_], _) :- !, r_comportamiento(M).
responder(_,         [M|_], _) :- !, r_ficha(M).
% --- Sin mob: preguntas por item o generales ---
responder(I, [], Ws) :-
    memberchk(I, [produce, alimento, ficha]),
    entidades_en_frase(item, Ws, [It|_]), !,
    r_quien_suelta(It).
responder(vida, [], Ws) :- !,
    (   ( memberchk(menos, Ws) ; memberchk(debil, Ws) ) -> r_extremo(menos) ; r_extremo(mas) ).
responder(I, [], Ws) :-
    categoria_en(Ws, C), !,
    filtrar_categoria(I, C).
responder(_, [], Ws) :-
    ( memberchk(lista, Ws) ; memberchk(todos, Ws) ; memberchk(cuantos, Ws) ; memberchk(mobs, Ws) ), !,
    r_todos.

categoria_en(Ws, pasivo)  :- ( memberchk(pasivo, Ws)  ; memberchk(pasivos, Ws) ), !.
categoria_en(Ws, neutral) :- ( memberchk(neutral, Ws) ; memberchk(neutrales, Ws) ), !.
categoria_en(Ws, hostil)  :- ( memberchk(hostil, Ws)  ; memberchk(hostiles, Ws) ; memberchk(peligrosos, Ws) ), !.
categoria_en(Ws, jefe)    :- ( memberchk(jefe, Ws)    ; memberchk(jefes, Ws) ), !.

% "que mobs hostiles se queman con el sol" -> cruza categoria con rasgo
filtrar_categoria(sol, C)       :- !, listar_filtro(C, se_quema_al_sol, 'se queman al sol').
filtrar_categoria(vuela, C)     :- !, listar_filtro(C, vuela, 'vuelan').
filtrar_categoria(no_muerto, C) :- !, listar_filtro(C, es_no_muerto, 'son no-muertos').
filtrar_categoria(agua, C)      :- !, listar_filtro(C, es_acuatico, 'son acuáticos').
filtrar_categoria(domestica, C) :- !, listar_filtro(C, es_domesticable, 'son domesticables').
filtrar_categoria(_, C)         :- r_categoria(C).

listar_filtro(C, P, Desc) :-
    findall(M, (categoria(M, C), call(P, M)), Ms), lista_txt(Ms, T),
    resp("Mobs ~w que ~w: ~w.", [C, Desc, T]).

no_entendi :-
    resp("No entendí la pregunta. Prueba con algo como:", []),
    forall(member(E, ['¿Qué come la vaca?', '¿Qué suelta el esqueleto?',
                    '¿Dónde aparece el blaze?', '¿A qué le teme el creeper?',
                    '¿Quién suelta pólvora?', '¿Es más resistente el warden o el wither?',
                    '¿Qué mobs hostiles se queman con el sol?']),
        format("     ~w~n", [E])).

% =====================================================================
% 5. MENU PRINCIPAL
% =====================================================================
iniciar_chatbot :-
    % Tildes y ñ correctas en entrada y salida
    catch(set_stream(user_input,  encoding(utf8)), _, true),
    catch(set_stream(user_output, encoding(utf8)), _, true),
    writeln('================================================='),
    writeln('      Bienvenido al Chatbot de Mobs Minecraft    '),
    writeln('================================================='),
    bucle_chat.

bucle_chat :-
    nl,
    writeln('Selecciona una opcion (sin punto final):'),
    writeln('  1. Que come / con que se cria un mob?'),
    writeln('  2. Que suelta / produce un mob?'),
    writeln('  3. El mob es pasivo, neutral, hostil o jefe?'),
    writeln('  4. Ficha completa de un mob'),
    writeln('  5. En que dimension aparece un mob?'),
    writeln('  6. Que mobs sueltan un item?'),
    writeln('  7. Listar mobs por categoria'),
    writeln('  8. De que huye / a quien ahuyenta un mob?'),
    writeln('  9. Comparar la vida de dos mobs'),
    writeln(' 10. Mob mas y menos resistente'),
    writeln(' 11. PREGUNTA LIBRE (lenguaje natural)'),
    writeln(' 12. Ver lista de todos los mobs'),
    writeln('  0. Salir'),
    leer_linea('Opcion: ', L),
    normalizar(L, Ws),
    (   Ws = [Op|_] -> true ; Op = invalida ),
    (   memberchk(Op, ['0', salir])
    ->  writeln('\n¡Hasta luego! Chatbot finalizado.')
    ;   ( catch(procesar_opcion(Op), E, print_message(error, E)) -> true ; true ),
        bucle_chat
    ).

procesar_opcion('1')  :- !, leer_mob(M), r_alimento(M).
procesar_opcion('2')  :- !, leer_mob(M), r_produce(M).
procesar_opcion('3')  :- !, leer_mob(M), r_comportamiento(M).
procesar_opcion('4')  :- !, leer_mob(M), r_ficha(M).
procesar_opcion('5')  :- !, leer_mob(M), r_dimension(M).
procesar_opcion('6')  :- !, leer_item(I), r_quien_suelta(I).
procesar_opcion('7')  :- !,
    leer_linea('Categoria (pasivo / neutral / hostil / jefe): ', L),
    normalizar(L, Ws),
    (   categoria_en(Ws, C) -> r_categoria(C)
    ;   resp("Categoría no válida.", []) ).
procesar_opcion('8')  :- !, leer_mob(M), r_huye(M).
procesar_opcion('9')  :- !,
    writeln('Primer mob:'),  leer_mob(A),
    writeln('Segundo mob:'), leer_mob(B),
    r_comparar(A, B).
procesar_opcion('10') :- !, r_extremo(mas), r_extremo(menos).
procesar_opcion('11') :- !,
    writeln('Escribe tu pregunta (o "volver" para el menu):'),
    bucle_libre.
procesar_opcion('12') :- !, r_todos.
procesar_opcion(_)    :- resp("Opción inválida. Intenta nuevamente.", []).

bucle_libre :-
    leer_linea('Tú: ', L),
    normalizar(L, Ws),
    (   ( Ws == [] ; Ws = [volver|_] ; Ws = [salir|_] ; Ws = [menu|_] )
    ->  true
    ;   responder_frase(L),
        nl, bucle_libre
    ).
