# ExActor

Simplified implementation and usage of `gen_server` based actors in Elixir.
This library is inspired by (though not depending on) [GenX](https://github.com/yrashk/genx), but in addition, removes some more boilerplate, and changes some semantics of the handle_call/cast responses.

If you're new to Erlang, and are not familiar on how gen_server works, I strongly suggest you learn about it first. It's really not that hard, and you can use [Elixir docs](http://elixir-lang.org/docs/stable/GenServer.Behaviour.html) as the starting point. Once you're familiar with gen_server, you can use ExActor to make your actors (gen_servers) more compact.

Status: I use it in production.

Online documentation is available [here](http://sasa1977.github.io/exactor/)

## Basic usage

```elixir
defmodule Actor do
  use ExActor.GenServer

  definit do: initial_state(some_state)

  defcast inc(x), state: state, do: new_state(state + x)

  defcall get, state: state, do: reply(state)
  defcall long_call, state: state, timeout: :timer.seconds(10), do: heavy_transformation(state)

  definfo :some_message, do: ...
end

# initial state is set to start argument
{:ok, act} = Actor.start(1)
Actor.get(act)         # 1

Actor.inc(act, 2)
Actor.get(act)         # 3
```

## Predefines

A predefine is an ExActor mixin that provides some default implementations for
`gen_server` callbacks. Following predefines are currently provided:

* `ExActor.GenServer` - All `gen_server` callbacks are provided by GenServer.Behaviour from Elixir standard library.
* `ExActor.Strict` - All `gen_server` callbacks are provided. The default implementations for all except `code_change` and `terminate` will cause the server to be stopped.
* `ExActor.Tolerant` - All `gen_server` callbacks are provided. The default implementations ignore all messages without stopping the server.
* `ExActor.Empty` - No default implementation for `gen_server` callbacks are provided.

It is up to you to decide which predefine you want to use. See online docs for detailed description.
You can also build your own predefine. Refer to the source code of the existing ones as a template.

## Singleton actors

```elixir
defmodule SingletonActor do
  # The actor process will be locally registered under an alias
  # given via export option
  use ExActor.GenServer, export: :some_registered_name

  defcall get, state: state, do: reply(state)
  defcast set(x), do: new_state(x)
end

SingletonActor.start
SingletonActor.set(5)
SingletonActor.get
```

## Handling of return values

```elixir
definit do: initial_state(arg)                      # sets initial state
definit do: {:ok, arg}                              # standard gen_server response

defcall a, state: state, do: reply(response)        # responds 5 but doesn't change state
defcall b, do: set_and_reply(new_state, response)   # responds and changes state
defcall c, do: {:reply, response, new_state}        # standard gen_server response

defcast c, do: noreply                              # doesn't change state
defcast d, do: new_state(new_state)                 # sets new state
defcast f, do: {:noreply, new_state}                # standard gen_server response

definfo c, do: noreply                              # doesn't change state
definfo d, do: new_state(new_state)                 # sets new state
definfo f, do: {:noreply, new_state}                # standard gen_server response
```

## Simplified starting

```elixir
Actor.start                           # same as Actor.start(nil)
Actor.start(init_arg)
Actor.start(init_arg, options)

Actor.start_link                      # same as Actor.start_link(nil)
Actor.start_link(init_arg)
Actor.start_link(init_arg, options)
```

## Simplified initialization

```elixir
# define initial state
use ExActor.GenServer, initial_state: HashDict.new

# alternatively as the function
definit do: HashSet.new

# using the input argument
definit x do
  x + 1
  |> initial_state
end
```

## Handling messages

```elixir
definfo :some_message, do:
definfo :another_message, state: ..., do:
```

## Pattern matching

```elixir
defcall a(1), do: ...
defcall a(2), do: ...
defcall a(x), state: 1, do: ...
defcall a(x), when: x > 1, do: ...
defcall a(x), state: state, when: state > 1, do: ...
defcall a(_), do: ...

definit :something, do: ...
definit x, when: ..., do: ...

definfo :msg, state: {...}, when: ..., do: ...
```

Note: all call/cast matches take place at the `handle_call` or `handle_cast` level. The interface function simply passes the arguments to appropriate `gen_server` function. Consequently, if a match fails, the server will crash.

## Skipping interface funs

```elixir
# interface fun will not be generated, just handle_call clause
defcall unexported, export: false, do: :unexported
```

## Using from

```
defcall a(...), from: {from_pid, ref} do
  ...
end
```

## Runtime friendliness

May be useful if calls/casts simply delegate to some module/functions.

```elixir
defmodule DynActor do
  use ExActor.GenServer

  for op <- [:op1, :op2] do
    defcall unquote(op), state: state do
      SomeModule.unquote(op)(state)
    end
  end
end
```


## Simplified data abstraction delegation

Macro `delegate_to` is provided to shorten the definition when the state is implemented as a functional data abstraction, and operations simply delegate to that module. Here's an example:

```elixir
defmodule HashDictActor do
  use ExActor.GenServer
  import ExActor.Delegator

  delegate_to HashDict do
    init
    query get/2
    trans put/3
  end
end
```

This is equivalent of:

```elixir
defmodule HashDictActor do
  use ExActor.GenServer

  definit do: HashDict.new

  defcall get(k), state: state do
    HashDict.get(state, k)
  end

  defcast put(k, v), state:state do
    HashDict.put(state, k, v)
    |> new_state
  end
end
```

You can freely mix `delegate_to` with other macros, such as `defcall`, `defcast`, and others.