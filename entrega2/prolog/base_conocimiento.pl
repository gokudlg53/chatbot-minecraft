%  BASE DE CONOCIMIENTO - MOBS DE MINECRAFT (Java Edition)
%  Solo HECHOS. Para agregar/modificar conocimiento se edita este archivo.
%  Convenciones:
%    - Nombres en minuscula, sin tildes, espacios -> guion bajo.
%    - vida/2 esta en puntos de vida (2 puntos = 1 corazon).
:- encoding(utf8).

:- discontiguous es_mob/1, categoria/2, vida/2, dimension/2.

% mob(Nombre, Categoria, Vida)  -> categoria: pasivo | neutral | hostil | jefe

% --- Pasivos ---
mob(vaca,               pasivo,  10).
mob(mooshroom,          pasivo,  10).
mob(pollo,              pasivo,   4).
mob(cerdo,              pasivo,  10).
mob(oveja,              pasivo,   8).
mob(conejo,             pasivo,   3).
mob(caballo,            pasivo,  15).
mob(burro,              pasivo,  15).
mob(gato,               pasivo,  10).
mob(ocelote,            pasivo,  10).
mob(zorro,              pasivo,  10).
mob(loro,               pasivo,   6).
mob(murcielago,         pasivo,   6).
mob(calamar,            pasivo,  10).
mob(tortuga,            pasivo,  30).
mob(ajolote,            pasivo,  14).
mob(rana,               pasivo,  10).
mob(armadillo,          pasivo,  12).
mob(camello,            pasivo,  32).
mob(sniffer,            pasivo,  14).
mob(aldeano,            pasivo,  20).
% --- Neutrales (atacan solo si se les provoca) ---
mob(lobo,               neutral,  8).
mob(abeja,              neutral, 10).
mob(oso_polar,          neutral, 30).
mob(enderman,           neutral, 40).
mob(piglin_zombificado, neutral, 20).
mob(delfin,             neutral, 10).
mob(golem_de_hierro,    neutral,100).
mob(llama,              neutral, 15).
mob(panda,              neutral, 20).
mob(cabra,              neutral, 10).
% --- Hostiles ---
mob(zombi,              hostil,  20).
mob(aldeano_zombi,      hostil,  20).
mob(ahogado,            hostil,  20).
mob(zombi_momificado,   hostil,  20).
mob(esqueleto,          hostil,  20).
mob(esqueleto_glacial,  hostil,  20).
mob(creeper,            hostil,  20).
mob(arana,              hostil,  16).
mob(bruja,              hostil,  26).
mob(slime,              hostil,  16).
mob(phantom,            hostil,  20).
mob(pececillo,          hostil,   8).
mob(saqueador,          hostil,  24).
mob(vindicador,         hostil,  24).
mob(evocador,           hostil,  24).
mob(devastador,         hostil, 100).
mob(guardian,           hostil,  30).
mob(guardian_anciano,   hostil,  80).
mob(warden,             hostil, 500).
mob(blaze,              hostil,  20).
mob(ghast,              hostil,  10).
mob(cubo_de_magma,      hostil,  16).
mob(esqueleto_wither,   hostil,  20).
mob(piglin,             hostil,  16).
mob(hoglin,             hostil,  40).
mob(shulker,            hostil,  30).
mob(endermite,          hostil,   8).
% --- Jefes ---
mob(dragon_ender,       jefe,   200).
mob(wither,             jefe,   300).

% Predicados derivados directos del hecho mob/3
es_mob(X)       :- mob(X, _, _).
categoria(X, C) :- mob(X, C, _).
vida(X, V)      :- mob(X, _, V).


% dimension(Mob, Dimension) -> overworld | nether | end

dimension(X, overworld) :-
    es_mob(X),
    \+ solo_otra_dimension(X).

solo_otra_dimension(X) :- member(X, [blaze, ghast, cubo_de_magma, esqueleto_wither,
                                     piglin, hoglin, piglin_zombificado,
                                     shulker, dragon_ender]).

dimension(blaze,              nether).
dimension(ghast,              nether).
dimension(cubo_de_magma,      nether).
dimension(esqueleto_wither,   nether).
dimension(piglin,             nether).
dimension(hoglin,             nether).
dimension(piglin_zombificado, nether).
dimension(enderman,           nether).
dimension(enderman,           end).
dimension(shulker,            end).
dimension(dragon_ender,       end).


% alimenta_con(Mob, Alimento) -> alimento usado para criar / reproducir

alimenta_con(vaca,      trigo).
alimenta_con(mooshroom, trigo).
alimenta_con(oveja,     trigo).
alimenta_con(cabra,     trigo).
alimenta_con(pollo,     semillas).
alimenta_con(cerdo,     zanahoria).
alimenta_con(cerdo,     papa).
alimenta_con(cerdo,     remolacha).
alimenta_con(conejo,    zanahoria).
alimenta_con(conejo,    diente_de_leon).
alimenta_con(caballo,   manzana_dorada).
alimenta_con(caballo,   zanahoria_dorada).
alimenta_con(burro,     manzana_dorada).
alimenta_con(burro,     zanahoria_dorada).
alimenta_con(llama,     fardo_de_heno).
alimenta_con(lobo,      carne).
alimenta_con(gato,      bacalao_crudo).
alimenta_con(gato,      salmon_crudo).
alimenta_con(ocelote,   bacalao_crudo).
alimenta_con(ocelote,   salmon_crudo).
alimenta_con(zorro,     bayas_dulces).
alimenta_con(panda,     bambu).
alimenta_con(tortuga,   algas_marinas).
alimenta_con(abeja,     flores).
alimenta_con(ajolote,   cubo_de_pez_tropical).
alimenta_con(rana,      bola_de_slime).
alimenta_con(armadillo, ojo_de_arana).
alimenta_con(camello,   cactus).
alimenta_con(sniffer,   semilla_de_flor_antorcha).
alimenta_con(hoglin,    hongo_carmesi).


% produce(Mob, Item) -> lo que suelta al morir o se obtiene de el

produce(vaca, cuero).                produce(vaca, carne_vacuna).
produce(vaca, leche).
produce(mooshroom, cuero).           produce(mooshroom, carne_vacuna).
produce(mooshroom, estofado_de_champinones).
produce(pollo, pluma).               produce(pollo, huevo).
produce(pollo, pollo_crudo).
produce(cerdo, chuleta_de_cerdo).
produce(oveja, lana).                produce(oveja, carne_de_cordero).
produce(conejo, piel_de_conejo).     produce(conejo, conejo_crudo).
produce(conejo, pata_de_conejo).
produce(caballo, cuero).             produce(burro, cuero).
produce(llama, cuero).
produce(gato, hilo).
produce(loro, pluma).
produce(calamar, saco_de_tinta).
produce(tortuga, algas_marinas).     produce(tortuga, escama_de_tortuga).
produce(rana, luz_de_rana).
produce(armadillo, escama_de_armadillo).
produce(sniffer, semilla_de_flor_antorcha).
produce(abeja, miel).                produce(abeja, panal).
produce(oso_polar, bacalao_crudo).   produce(oso_polar, salmon_crudo).
produce(delfin, bacalao_crudo).
produce(golem_de_hierro, lingote_de_hierro).
produce(golem_de_hierro, amapola).
produce(enderman, perla_de_ender).
produce(piglin_zombificado, carne_podrida).
produce(piglin_zombificado, pepita_de_oro).
produce(zombi, carne_podrida).
produce(aldeano_zombi, carne_podrida).
produce(zombi_momificado, carne_podrida).
produce(ahogado, carne_podrida).     produce(ahogado, lingote_de_cobre).
produce(ahogado, tridente).
produce(esqueleto, hueso).           produce(esqueleto, flecha).
produce(esqueleto_glacial, hueso).   produce(esqueleto_glacial, flecha).
produce(esqueleto_glacial, flecha_de_lentitud).
produce(creeper, polvora).
produce(arana, hilo).                produce(arana, ojo_de_arana).
produce(bruja, botella_de_vidrio).   produce(bruja, polvo_de_redstone).
produce(bruja, azucar).              produce(bruja, polvora).
produce(slime, bola_de_slime).
produce(phantom, membrana_de_phantom).
produce(saqueador, ballesta).        produce(saqueador, flecha).
produce(vindicador, esmeralda).
produce(evocador, totem_de_inmortalidad). produce(evocador, esmeralda).
produce(devastador, montura).
produce(guardian, fragmento_de_prismarina). produce(guardian, pescado_crudo).
produce(guardian_anciano, esponja_mojada).
produce(guardian_anciano, fragmento_de_prismarina).
produce(warden, catalizador_de_sculk).
produce(blaze, vara_de_blaze).
produce(ghast, lagrima_de_ghast).    produce(ghast, polvora).
produce(cubo_de_magma, crema_de_magma).
produce(esqueleto_wither, carbon).   produce(esqueleto_wither, hueso).
produce(esqueleto_wither, craneo_de_esqueleto_wither).
produce(hoglin, chuleta_de_cerdo).   produce(hoglin, cuero).
produce(shulker, caparazon_de_shulker).
produce(dragon_ender, huevo_de_dragon).
produce(wither, estrella_del_nether).

% Items que se pueden comer o beber
es_comestible(carne_vacuna).    es_comestible(chuleta_de_cerdo).
es_comestible(pollo_crudo).     es_comestible(carne_de_cordero).
es_comestible(conejo_crudo).    es_comestible(bacalao_crudo).
es_comestible(salmon_crudo).    es_comestible(carne_podrida).
es_comestible(estofado_de_champinones). es_comestible(leche).
es_comestible(miel).            es_comestible(pescado_crudo).


% Caracteristicas / comportamientos

es_domesticable(lobo).   es_domesticable(gato).   es_domesticable(caballo).
es_domesticable(burro).  es_domesticable(llama).  es_domesticable(loro).

es_montable(caballo). es_montable(burro). es_montable(llama).
es_montable(cerdo).   es_montable(camello).

es_no_muerto(zombi).            es_no_muerto(aldeano_zombi).
es_no_muerto(ahogado).          es_no_muerto(zombi_momificado).
es_no_muerto(esqueleto).        es_no_muerto(esqueleto_glacial).
es_no_muerto(esqueleto_wither). es_no_muerto(piglin_zombificado).
es_no_muerto(phantom).          es_no_muerto(wither).

se_quema_al_sol(zombi).    se_quema_al_sol(aldeano_zombi).
se_quema_al_sol(ahogado).  se_quema_al_sol(esqueleto).
se_quema_al_sol(esqueleto_glacial). se_quema_al_sol(phantom).

vuela(murcielago). vuela(abeja). vuela(loro). vuela(phantom).
vuela(ghast). vuela(blaze). vuela(dragon_ender). vuela(wither).

es_acuatico(calamar). es_acuatico(delfin). es_acuatico(ajolote).
es_acuatico(tortuga). es_acuatico(ahogado). es_acuatico(guardian).
es_acuatico(guardian_anciano).

danado_por_agua(enderman). danado_por_agua(blaze).

ataca_a_distancia(esqueleto). ataca_a_distancia(esqueleto_glacial).
ataca_a_distancia(bruja).     ataca_a_distancia(blaze).
ataca_a_distancia(ghast).     ataca_a_distancia(saqueador).
ataca_a_distancia(guardian).  ataca_a_distancia(guardian_anciano).
ataca_a_distancia(shulker).   ataca_a_distancia(llama).
ataca_a_distancia(evocador).  ataca_a_distancia(warden).
ataca_a_distancia(wither).    ataca_a_distancia(dragon_ender).

explota(creeper).

participa_en_asalto(saqueador). participa_en_asalto(vindicador).
participa_en_asalto(evocador).  participa_en_asalto(devastador).
participa_en_asalto(bruja).

% huye_de(Mob, Otro) -> Mob escapa cuando Otro esta cerca
huye_de(creeper, gato).          huye_de(creeper, ocelote).
huye_de(phantom, gato).
huye_de(esqueleto, lobo).        huye_de(esqueleto_glacial, lobo).
huye_de(esqueleto_wither, lobo).
huye_de(conejo, lobo).           huye_de(lobo, llama).
huye_de(aldeano, zombi).         huye_de(aldeano, aldeano_zombi).
huye_de(aldeano, saqueador).     huye_de(aldeano, vindicador).
