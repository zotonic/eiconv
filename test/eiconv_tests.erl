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

null_byte_encoding_name_test() ->
    ?assertError(badarg, eiconv:open(<<"utf-8\0evil">>, "ascii")),
    ?assertError(badarg, eiconv:open("utf-8", <<"ascii\0evil">>)),
    ?assertError(badarg, eiconv:open([<<"utf-8">>, 0, <<"evil">>], "ascii")),
    ?assertError(badarg, eiconv:convert(<<"utf-8\0evil">>, "ascii", "123")),
    ?assertError(badarg, eiconv:convert("utf-8", <<"ascii\0evil">>, "123")),
    ok.

non_existing_codecs_test() ->
    ?assertEqual({error, einval}, eiconv:open("utf-9", "utf-15")),
    ?assertEqual({error, einval}, eiconv:open("utf-8", "iso8859-23")),
    ?assertEqual({error, einval}, eiconv:open("iso8859-23", "utf-8")).

blocked_codecs_test() ->
    ?assertEqual({error, einval}, eiconv:open("iso-2022-cn-ext", "utf-8")),
    ?assertEqual({error, einval}, eiconv:open("ISO-2022-CN", "utf-8")),
    ?assertEqual({error, einval}, eiconv:open("ISO_2022_CN", "utf-8")),
    ?assertEqual({error, einval}, eiconv:open("ISO2022CN", "utf-8")),
    ?assertEqual({error, einval}, eiconv:open("cs-iso-2022-cn", "utf-8")),
    ?assertEqual({error, einval}, eiconv:open("ISO-2022-CN//TRANSLIT", "utf-8")),
    ?assertEqual({error, einval}, eiconv:open("ISO-2022-CN-EXT//IGNORE", "utf-8")),
    ?assertEqual({error, einval}, eiconv:open("utf-8", "iso-2022-cn-ext")),
    ?assertEqual({error, einval}, eiconv:open("utf-8", "ISO-2022-CN")),
    ?assertEqual({error, einval}, eiconv:open("utf-8", "ISO2022CN")),
    ?assertEqual({error, einval}, eiconv:convert("iso-2022-cn-ext", "utf-8", "test")),
    ?assertEqual({error, einval}, eiconv:convert("utf-8", "iso-2022-cn-ext", "test")),
    ok.

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
-dialyzer({nowarn_function, restbuf_badarg_safety_test/0}).
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
-dialyzer({nowarn_function, concurrent_converter_access_test/0}).
concurrent_converter_access_test() ->
    {ok, C} = eiconv:open("utf8", "iso8859-15"),
    Self = self(),
    NumWorkers = 10,
    NumIterations = 1000,
    Pids = [
        spawn_link(fun() ->
            lists:foreach(
                fun(_) ->
                    case eiconv:chunk(C, [163, 164, 165]) of
                        {done, <<194, 163, 226, 130, 172, 194, 165>>} -> ok;
                        Other -> exit({unexpected_chunk, Other})
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
