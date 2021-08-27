-module(demo_schema2).

-include_lib("typerefl/include/types.hrl").

-behaviour(hocon_schema).

-export([roots/0, fields/1]).

roots() ->
    [ {foo, hoconsc:array(hoconsc:ref(foo))}
    , {"kek", hoconsc:lazy(hoconsc:union([bar, "kak"]))}
    ].

fields(foo) ->
    [ {int, integer()}
    ];
fields(bar) ->
    [{bint, integer()}];
fields("kak") ->
    [{kint, integer()}].
