defmodule Exedra.ANSI do
  def colors, do: %{
        black: "\x1b[0;30m",
        darkred: "\x1b[0;31m",
        darkgreen: "\x1b[0;32m",
        brown: "\x1b[0;33m",
        darkblue: "\x1b[0;34m",
        darkpink: "\x1b[0;35m",
        darkcyan: "\x1b[0;36m",
        grey: "\x1b[0;37m",
        darkgrey: "\x1b[1;30m",
        red: "\x1b[1;31m",
        green: "\x1b[1;32m",
        yellow: "\x1b[1;33m",
        blue: "\x1b[1;34m",
        pink: "\x1b[1;35m",
        cyan: "\x1b[1;36m",
        white: "\x1b[0;30m",
        reset: "\x1b[0m"
  }
end
