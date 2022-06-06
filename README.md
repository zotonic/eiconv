[![Build Status][gh badge]][gh]
[![Hex.pm version][hexpm version]][hexpm]
[![Hex.pm Downloads][hexpm downloads]][hexpm]
[![Hex.pm Documentation][hexdocs documentation]][hexdocs]
[![Erlang Versions][erlang version badge]][gh]
[![License][license]](https://www.apache.org/licenses/LICENSE-2.0)

# Erlang NIF wrapper for iconv

An Erlang wrapper for the character set conversion utility [iconv](https://en.wikipedia.org/wiki/Iconv).

## Getting started

### Include as a dependency

Using [rebar3](http://www.rebar3.org/), add the dependency to your `rebar.config` file:

```erlang
{deps, [
    {eiconv, "1.0.0"},
    %% ...
]}.
```

and run `$ rebar3 compile`.

### Use `eiconv` module

To convert from `utf-8` to `ascii`:

```erlang
ToConvert = "123",
{ok, Converted} = eiconv:convert("utf-8", "ascii", ToConvert)),
io:format("Converted '~s' to '~s'~n", [ToConvert, Converted])
```

## `eiconv` API

### Using `convert/3`

```erlang
{ok, Converted} = eiconv:convert("utf-8", "ascii", "123"))
```

### Using CD (Conversion Descriptor)

```erlang
{ok, CD} = eiconv:open("utf8", "ascii"),
{ok, Converted} = eiconv:conv(CD, "123")),
ok = eiconvclose(CD)
```

## `iconv` API

### Using `convert/3`

```erlang
Converted = eiconv:convert("utf-8", "ascii", "123"))
```

(Note it return directly the converted text and not a tuple {ok, Converted})

## Authors

Wrapper provided by Maas-Maarten Zeeman and the [Zotonic](https://github.com/zotonic) team.

* [Maas-Maarten Zeeman](https://github.com/mmzeeman)
* [Arjan Scherpenisse](https://github.com/arjan)
* [Marc Worrell](https://github.com/mworrell)

<!-- Badges -->
[hexpm]: https://hex.pm/packages/eiconv
[hexpm version]: https://img.shields.io/hexpm/v/eiconv.svg?style=flat-curcle "Hex version"
[hexpm downloads]: https://img.shields.io/hexpm/dt/eiconv.svg?style=flat-curcle
[hexdocs documentation]: https://img.shields.io/badge/hex-docs-purple.svg?style=flat-curcle
[hexdocs]: https://hexdocs.pm/eiconv
[gh]: https://github.com/zotonic/eiconv/actions/workflows/test.yaml
[gh badge]: https://github.com/zotonic/eiconv/workflows/Test/badge.svg
[erlang version badge]: https://img.shields.io/badge/Supported%20Erlang%2FOTP-19%20to%2023-blue.svg?style=flat-curcle
[license]: https://img.shields.io/badge/License-Apache_2.0-blue.svg?logo=apache&logoColor=red "Apache 2.0"