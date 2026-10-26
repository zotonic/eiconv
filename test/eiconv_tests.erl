%%
%% Test suite for eiconv...
%%

-module(eiconv_tests).

-include_lib("eunit/include/eunit.hrl").

conv(C, I) ->
    {ok, R} = eiconv:conv(C, I),
    R.

%% Some simple tests...
ascii_to_utf8_test() ->
    {ok, C} = eiconv:open("utf8", "ascii"),
    ?assertEqual(<<"123">>, conv(C, "123")),
    ?assertEqual(<<"123">>, conv(C, ["123"])),
    ?assertEqual(<<"123">>, conv(C, <<"123">>)).

iso8859_15_to_utf8_test() ->
    {ok, C} = eiconv:open("utf8", "iso8859-15"),
    ?assertEqual(<<194, 163,  226, 130, 172,  194, 165>>,
        conv(C, [163, 164, 165])).

iso8859_15_to_utf8_chunks_test() ->
    % convert byte for byte
    Chunk = fun(C, I) ->
        {ok, R} = eiconv:conv(C, I, 1),
        R
    end,

    {ok, C1} = eiconv:open("utf8", "iso8859-15"),
    ?assertEqual(<<194, 163,  226, 130, 172,  194, 165>>, Chunk(C1, [163, 164, 165])),

    {ok, C2} = eiconv:open("iso8859-15", "utf8"),
    ?assertEqual(<<163,  164, 165>>, Chunk(C2, [194, 163, 226, 130, 172, 194, 165])),
    ok.

utf8_to_iso8859_15_test() ->
    {ok, C} = eiconv:open("iso8859-15", "utf8"),
    ?assertEqual(<<163,  164, 165>>, conv(C, [194, 163, 226, 130, 172, 194, 165])).

non_existing_codecs_test() ->
    ?assertEqual({error, einval}, eiconv:open("utf-9", "utf-15")),
    ?assertEqual({error, einval}, eiconv:open("utf-8", "iso8859-23")),
    ?assertEqual({error, einval}, eiconv:open("iso8859-23", "utf-8")).

convert_encoding_test() ->
    ?assertEqual({error, einval}, eiconv:convert("utf-9", "Test, 123")),
    ?assertEqual({error, einval}, eiconv:convert("utf-8", "non-existent", "Test, 123")),
    ?assertEqual({ok, <<"123">>}, eiconv:convert("utf-8", "ascii", "123")),
    ?assertEqual({ok, <<"123">>}, eiconv:convert("ascii", "123")).

iso8859_15_to_utf8_chunk_test() ->
    {ok, C} = eiconv:open("utf8", "iso8859-15"),
    ?assertEqual({done,<<194,163,226,130,172,194,165>>},
        eiconv:chunk(C, [163, 164, 165])),
    ?assertEqual(ok, eiconv:finalize(C)),

    %% Converting in chunks
    ?assertEqual({done,<<194,163>>}, eiconv:chunk(C, [163])),
    ?assertEqual({done,<<226,130,172>>}, eiconv:chunk(C, [164])),
    ?assertEqual({done,<<194,165>>}, eiconv:chunk(C, [165])),
    ?assertEqual(ok, eiconv:finalize(C)),
    ok.

incomplete_chunk_test() ->
    {ok, C} = eiconv:open("iso8859-15", "utf8"),
    ?assertEqual({more, <<"AB">>}, eiconv:chunk(C, <<65, 66, 194>>)),
    ?assertEqual({done, <<163>>}, eiconv:chunk(C, <<163>>)),
    ?assertEqual({more, <<>>}, eiconv:chunk(C, <<226, 130>>)),
    ?assertEqual({done, <<164>>}, eiconv:chunk(C, <<172>>)),
    ?assertEqual({done, <<165>>}, eiconv:chunk(C, [194, 165])),
    ?assertEqual(ok, eiconv:finalize(C)),
    ok.

%% Finding 1: Calling chunk with an invalid argument when restbuf holds an incomplete
%% character should not corrupt restbuf or cause double-free on subsequent operations or GC.
restbuf_badarg_safety_test() ->
    {ok, C} = eiconv:open("iso8859-15", "utf8"),
    %% Feed incomplete UTF-8 sequence, leaving <<194>> in restbuf:
    ?assertEqual({more, <<"AB">>}, eiconv:chunk(C, <<65, 66, 194>>)),
    %% Pass an invalid iolist argument (raises badarg):
    ?assertError(badarg, eiconv:chunk(C, invalid_term)),
    %% A subsequent chunk call completes the character sequence and finalize cleans up:
    ?assertEqual({done, <<163>>}, eiconv:chunk(C, <<163>>)),
    ?assertEqual(ok, eiconv:finalize(C)),
    erlang:garbage_collect(),
    ok.

%% Finding 2: Concurrent use of a shared converter descriptor.
%% Multiple processes using the same Cd concurrently should be thread-safe
%% and not corrupt internal conversion state or crash with eilseq.
concurrent_converter_access_test() ->
    {ok, C} = eiconv:open("iso8859-15", "utf8"),
    Self = self(),
    NumWorkers = 10,
    NumIterations = 100,
    Pids = [
        spawn_link(fun() ->
            lists:foreach(
                fun(_) ->
                    case eiconv:chunk(C, <<65, 66, 194>>) of
                        {more, <<"AB">>} -> ok;
                        Other1 -> exit({unexpected_chunk1, Other1})
                    end,
                    case eiconv:chunk(C, <<163>>) of
                        {done, <<163>>} -> ok;
                        Other2 -> exit({unexpected_chunk2, Other2})
                    end
                end,
                lists:seq(1, NumIterations)
            ),
            Self ! {done, self()}
        end)
     || _ <- lists:seq(1, NumWorkers)
    ],
    [receive {done, Pid} -> ok end || Pid <- Pids],
    ?assertEqual(ok, eiconv:finalize(C)).

%% Finding 4: iconv return value check (rc == 0 vs rc != (size_t)(-1)).
%% When transliteration is used, iconv performs non-identical conversion and returns
%% rc > 0. The current code assumes any rc != 0 is an error, failing with {error, eunknown}.
transliteration_return_value_test() ->
    case eiconv:open("ascii//translit", "utf-8") of
        {ok, C} ->
            ?assertEqual({done, <<"hello EUR world">>},
                         eiconv:chunk(C, <<"hello € world"/utf8>>)),
            ?assertEqual(ok, eiconv:finalize(C));
        {error, einval} ->
            %% Some libc implementations do not support //translit suffix
            ok
    end.
