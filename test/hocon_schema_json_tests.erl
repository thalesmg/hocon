%%--------------------------------------------------------------------
%% Copyright (c) 2022-2023 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(hocon_schema_json_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("typerefl/include/types.hrl").

tags_test_() ->
    [
        {"no tags function exported", ?_assertMatch([#{tags := []} | _], gen(demo_schema2))},
        {"with tags function exported", fun() ->
            Json = gen(demo_schema3),
            ?assertMatch([#{tags := []} | _], Json),
            [_Root | Rest] = Json,
            lists:foreach(
                fun(Struct) ->
                    ?assertMatch(
                        #{tags := [<<"tag1">>, <<"another tag">>]},
                        Struct
                    )
                end,
                Rest
            )
        end},
        {"with references to schemas with different tags", fun() ->
            Json = gen(demo_schema4),
            ?assertMatch([#{tags := []}, _, _], Json),
            [_Root, Schema4Struct, Schema5Struct] = Json,
            ?assertMatch(#{tags := [<<"tag from demo_schema4">>]}, Schema4Struct),
            ?assertMatch(#{tags := [<<"tag from demo_schema5">>]}, Schema5Struct),
            ok
        end}
    ].

unique_field_names_test() ->
    Structs = #{
        foo => [
            {id, hoconsc:mk(integer(), #{default => 12})},
            {id, hoconsc:mk(string(), #{default => 12})}
        ]
    },
    Sc = #{
        roots => [{"root", hoconsc:mk(hoconsc:ref(foo), #{required => false})}],
        fields => Structs
    },
    ?assertThrow(
        #{
            duplicated := [<<"id">>],
            path := <<"foo">>,
            reason := duplicated_field_names_and_aliases
        },
        gen(Sc)
    ).

unique_field_name_with_aliases_test() ->
    Structs = #{
        foo => [
            {id, hoconsc:mk(integer(), #{default => 12})},
            {id2, hoconsc:mk(string(), #{default => 12, aliases => ["id"]})}
        ]
    },
    Sc = #{
        roots => [{"root", hoconsc:mk(hoconsc:ref(foo), #{required => false})}],
        fields => Structs
    },
    ?assertThrow(
        #{
            duplicated := [<<"id">>],
            path := <<"foo">>,
            reason := duplicated_field_names_and_aliases
        },
        gen(Sc)
    ).

hidden_structs_test() ->
    Structs = #{
        foo => [{id, hoconsc:mk(integer(), #{default => 12})}],
        foo_hidden => [{id, hoconsc:mk(integer(), #{default => 12, hidden => true})}],
        bar => [{to_foo, hoconsc:mk(hoconsc:ref(foo_hidden), #{})}],
        baz => [{to_foo_hidden, hoconsc:mk(hoconsc:ref(foo), #{hidden => true})}]
    },
    Sc = #{
        roots => [
            {"hidden", hoconsc:mk(hoconsc:ref(foo), #{required => false, hidden => true})},
            {"nested_hidden1", hoconsc:mk(hoconsc:ref(bar), #{required => false, hidden => false})},
            {"nested_hidden2", hoconsc:mk(hoconsc:ref(baz), #{required => false, hidden => false})},
            {"visible", hoconsc:mk(hoconsc:ref(foo), #{required => false})}
        ],
        fields => Structs
    },
    Json = gen(Sc),
    ?assertMatch(
        [
            #{
                fields := [
                    #{name := <<"nested_hidden1">>},
                    #{name := <<"nested_hidden2">>},
                    #{name := <<"visible">>}
                ],
                full_name := <<"Root Config Keys">>
            },
            #{
                fields := [#{name := <<"to_foo">>}],
                full_name := <<"bar">>,
                paths := [<<"nested_hidden1">>]
            },
            #{
                fields := [#{name := <<"id">>}],
                full_name := <<"foo">>,
                paths := [<<"visible">>]
            }
        ],
        Json
    ).

gen(Schema) ->
    hocon_schema_json:gen(Schema).
