%%% Copyright 2011, 2012, 2013 Maas-Maarten Zeeman
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
%%% @doc drop in replacement module.
%%%

-module(iconv).
-author("Maas-Maarten Zeeman <mmzeeman@xs4all.nl>").

-export([open/2, conv/2, close/1, convert/3]).

open(ToCode, FromCode) ->
    eiconv:open(ToCode, FromCode).

conv(Cd, Input) ->
    eiconv:conv(Cd, Input).

close(Cd) ->
    eiconv:close(Cd).

% @doc Convert input which is in FromEncoding to ToEncoding.
%
convert(FromEncoding, ToEncoding, Input) ->
    case eiconv:convert(FromEncoding, ToEncoding, Input) of
        {ok, Output} -> Output;
        {error, Error} ->
            % throw the original error.
            % TODO Let the badmatch occur?
            % But it is not easy to catch by the user.
            erlang:throw(Error)
    end.
