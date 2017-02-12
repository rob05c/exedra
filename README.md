# Exedra

Exedra is a MUD (online text game) over SSH, in Elixir.

Exedra is currently in the infantile stages. SSH login exists, with a rudimentary REPL prompt, but nothing else.

## Installation

Install Elixir ≥ 1.3.4

Install OpenSSL

Get the code
```
$ git clone https://github.com/rob05c/exedra
```

Get the dependencies

```
$ cd exedra

$ mix deps.get
```

Generate the SSH server key
```
$ ./keygen
```

Run the service

```
$ iex -S mix
```

Test (in another terminal)

```
ssh -p 42424 localhost -l bill
thelizard
```

## Configuration

Configuration is done via `config/config.exs`

`port` - the port to serve on
`credentials` - a list of {user, password} tuples

## Credits

Thanks to [ex_sshd](https://github.com/tverlaan/ex_sshd) for the example code for an Elixir newbie like myself to get Erlang SSH with a custom shell working.
