# acoc - arbitrary command output colourer

`acoc` is a regular expression based colour formatter for programs
that display output on the command-line.

It works as a wrapper around the target program, executing it
and capturing the stdout stream. Optionally, stderr can
be redirected to stdout, so that it, too, can be manipulated.

`acoc` then applies matching rules to patterns in the output
and applies colour sets to those matches.

## Usage

Just call the command you want to color after `acoc`.
Arguments are passed normally:

    acoc command [arg1 .. argN]

`acoc` supports the following command-line options:

| Option              | Description |
| ------------------- | ----------- |
|`-h` or `--help`     | Display usage information.   |
| `-v` or `--version` | Display version information. |


## Installation

    $ gem install acoc

## Configuration

### Files

By reading the regular expressions on the configuration file,
`acoc` decides how to color the output. Here's the order of
reading:

1. `/usr/local/etc/acoc.conf`
2. `/etc/acoc.conf`
3. `~/.acoc.conf`

When you run `acoc` for the first time, an example file will
be placed on your home directory.

### Environment Variables

`acoc` also responds to environment variables. You'd normally
use them like this:

    $ export VAR="value"
    $ acoc

If `ACOC` is set to `none`, no colouring will be performed.

If `ACOCRC` is set, specifies the location of an additional
configuration file.

## Contributing

`acoc` is only as good as the configuration file that it uses.
If you compose pattern-matching rules that you think would be
useful to other people, please
[send them to me](mailto:ian@caliban.net) for inclusion in a
subsequent release.

## Bugs

* Nested regular expressions do not work well.
  Inner subexpressions need to use clustering (?:),
  not capturing ().
  In other words, they can be used for matching,
  but not for colouring.

## Author

`acoc` was written by Ian Macdonald <ian@caliban.org>

The Ruby Gem was made by Alexandre Dantas <eu@alexdantas.net>

* [acoc home page](http://www.caliban.org/ruby/)
* [Term::ANSIColor](http://raa.ruby-lang.org/list.rhtml?name=ansicolor)
* [Ruby/TPty](http://www.tmtm.org/ruby/tpty/)

## License

 Copyright (C) 2003-2004 Ian Macdonald

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software Foundation,
Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

