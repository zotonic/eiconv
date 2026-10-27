%%% Copyright 2011-2026 Maas-Maarten Zeeman
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%% 
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%% 
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%
%%% @author Maas-Maarten Zeeman <mmzeeman@xs4all.nl>
%%% @doc eiconv module.
%%%
%%% <h3>There two type of APIs:</h3>
%%% <ul>
%%%   <li><b>Easy API one shot convert API:</b>
%%%     <ul>
%%%       <li>{@link convert/2}</li>
%%%       <li>{@link convert/3}</li>
%%%     </ul>
%%%   </li>
%%%   <li><b>Old iconv compatible API:</b>
%%%     <ul>
%%%       <li>{@link open/2}</li>
%%%       <li>{@link conv/2}</li>
%%%       <li>{@link conv/3}</li>
%%%       <li>{@link close/1}</li>
%%%     </ul>
%%%   </li>
%%% </ul>

-module(eiconv).
-author("Maas-Maarten Zeeman <mmzeeman@xs4all.nl>").

% easy api one shot convert api
-export([convert/2, convert/3]).

% old iconv compatible api
-export([open/2, conv/2, conv/3, close/1]).

% low level api.
-export([chunk/2, finalize/1]).

-define(DEFAULT_CHUNK_SIZE, 1024 * 128).

-on_load(init/0).

%% @private
%% @doc Load the <abbr title="native implementation of a function">NIF</abbr>

init() ->
    NifName = "eiconv_nif",
    NifFileName = case code:priv_dir(eiconv) of
        {error, bad_name} -> filename:join(["priv", NifName]);
        Dir -> filename:join([Dir, NifName])
    end,

    ok = erlang:load_nif(NifFileName, 0).

%% @doc Open a new encoder which can be used to convert text from `FromCode' into `ToCode'.
-spec open(ToEncoding, FromEncoding) -> Result when
    ToEncoding :: iodata(), 
    FromEncoding :: iodata(), 
    Result :: {ok, reference()} | {error, term()}.
open(_ToCode, _FromCode) ->
    erlang:nif_error(nif_library_not_loaded).

%% @private
%% @doc Convert a chunk, returns `{done, ConvertedBytes} | {more, Converted}
%%       | {error, Reason} | {error, Reason, Converted}'
%%
%%       `Converted' in the error case contains the bytes converted before
%%       an invalid input sequence was found.
-spec chunk(Cd, Input) -> Result when
      Cd :: reference(),
      Input :: iodata(),
      Result :: {done, binary()} | {more, binary()} | {error, term()}
              | {error, term(), binary()}.
chunk(_Cd, _Input) ->
    erlang:nif_error(nif_library_not_loaded).

%% @private
%% @doc Reset the cd structure, 
%% @returns `ok | {rest, LeftOverBytes}'
-spec finalize(Cd) -> Result when
      Cd :: reference(),
      Result :: ok | {rest, binary()}.
finalize(_Cd) ->
    erlang:nif_error(nif_library_not_loaded).

%% @doc Convert Input into the requested encoding.

conv(Cd, Input) ->
    conv(Cd, Input, ?DEFAULT_CHUNK_SIZE).

%% @doc Convert input. The input will first be split into 
%% chunks of `ChunkSize' before being converted by the nif.

conv(Cd, Input, ChunkSize) ->
    Chunks = split_input(ChunkSize, Input),
    case conv1(Cd, Chunks, []) of
        {ok, Converted} -> 
            {ok, erlang:iolist_to_binary(Converted)};
        {error,_}=Error -> 
            Error
    end.
    
conv1(Cd, [], Acc) ->
    case finalize(Cd) of
        ok ->
            {ok, lists:reverse(Acc)};
        {rest, _} ->
            {error, einval}
    end;
conv1(Cd, [H|T], Acc) ->
    case chunk(Cd, H) of
        {error, Reason} ->
            {error, Reason};
        {error, Reason, _Converted} ->
            %% Chunk conversion failed on an invalid input sequence. The
            %% converted prefix is discarded to keep the return value of
            %% conv/2,3 backwards compatible; callers of the low level
            %% chunk/2 api do receive it.
            {error, Reason};
        {What, <<>>} when What =:= done orelse What =:= more ->
            conv1(Cd, T, Acc);
        {What, Result} when What =:= done orelse What =:= more ->
            conv1(Cd, T, [Result | Acc])
    end.

%% @doc Close the encoder - dummy function, close will be done by the garbage collector.

close(_Cd) ->
    ok.

%% @doc Convert input `FromEncoding' to `utf-8'
%% @equiv convert(FromEncoding, "utf-8", Input)
-spec convert(FromEncoding, Input) -> Result when
    FromEncoding :: iodata(), 
    Input :: iodata(),
    Result :: {ok, binary()} | {error, Error},
    Error :: term().
convert(FromEncoding, Input) ->
    convert(FromEncoding, "utf-8", Input).

%% @doc Convert `Input' which is in `FromEncoding' to `ToEncoding'.
-spec convert(FromEncoding, ToEncoding, Input) -> Result when
    FromEncoding :: iodata(), 
    ToEncoding :: iodata(), 
    Input :: iodata(),
    Result :: {ok, binary()} | {error, Error},
    Error :: term().
convert(FromEncoding, ToEncoding, Input) ->
    case open(ToEncoding, FromEncoding) of
        {ok, Cd} ->
            conv(Cd, Input);
        {error, _}=Error ->
            Error
    end.

%% Helpers

split_input(MaxSize, Input) when MaxSize > 0 ->
    case iolist_to_binary(Input) of
        <<Chunk:MaxSize/binary, Rest/binary>> ->
            [Chunk | split_input(MaxSize, Rest)];
        Chunk -> [Chunk]
    end.

