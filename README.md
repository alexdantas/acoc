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

For example, to color the output of the `ping` command, do:

    acoc ping http://host.com -c 3

`acoc` supports the following command-line options:

| Option              | Description |
| ------------------- | ----------- |
|`-h` or `--help`     | Display usage information.   |
| `-v` or `--version` | Display version information. |

## Installation

`acoc` depends on the [Term::ANSIColor][term] module. Installing it as a RubyGem
should solve all dependencies, though:

    $ gem install acoc

`acoc` can also make use of [Masahiro Tomita's Ruby/TPty][tpty] library to
allocate pseudo-terminals in order to fool those programs that behave
differently if their *stdout* stream is not connected to a tty.  `ls` is one
such program.

Whilst `Ruby/TPty` is not mandatory (`acoc` will ignore its absence),
it's installation is recommended in order to improve the
transparency of `acoc`'s operation.

## Configuration

Out-of-the-box, `acoc` provides coloring for the following commands:

* diff
* ping
* traceroute
* make, configure
* rpm, rmpbuild
* w, top, df
* vmstat
* nmap, netstat
* ifconfig, route, tcpdump
* gcc, ldd, nm
* strace, ltrace
* id, ps
* apt-cache search, apt-cache show
* apt-get install, apt-get remove
* lsmod, whereis

You can customize it to color the output of any command you want.
To do so, follow the steps:

1. Open one of the configuration files (see below);
2. Add a _section_ to the program you want;
3. Add a _regular expression_, marking important parts, followed by _their
   colors_;

For example, the command `mount` outputs the following:

    $ mount
	proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
	sys on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
	...
	/dev/sda2 on /home type ext4 (rw,relatime,data=ordered)

Note that it has a well-defined structure - it's quite like this:

    "A" on "B" type "C" ("D")

So to make _the first block cyan_, _the second block blue_ and the _third block
red_, add the following to the configuration file:

    # My custom colors for "mount"
    [mount]
    /^(.*) on (.*) .*$/  cyan,blue+bold
    /type (.*)/          red

Note that you can put as many regular expressions as you want
inside the command section. Last ones have higher precedence.

So, here's the rules:

* **Command**: must be between `[]`s;
* **Regular Expression*: must be between `//`s;
* **Colors**: must be in a whole block (cannot have spaces);

### Files

By reading the regular expressions on the configuration file,
`acoc` decides how to color the output. Here's the order of
reading:

1. `/usr/local/etc/acoc.conf`
2. `/etc/acoc.conf`
3. `~/.acoc.conf`

**NOTE:** When you run `acoc` for the first time, it places an
example file on your home directory. Instructions on how to
customize and add your commands are included there.

### Environment Variables

`acoc` also responds to environment variables. You'd normally
use them like this:

    $ export VAR="value"
    $ acoc

If `ACOC` is set to `none`, no colouring will be performed.

If `ACOCRC` is set, specifies the location of an additional
configuration file.

## Screenshots

**traceroute (green = fast, red = slow)**
![traceroute](http://caliban.org/images/traceroute.png)

**w (neat colors)**
![w](http://caliban.org/images/w.png)

**top (with root's processes shown in red)**
![top](http://caliban.org/images/top.png)

## Contributing

`acoc` is only as good as the configuration file that it uses. Please share your
pattern-matching rules, it could be very helpful for everyone!

To share (and see other community-created patterns), go to
[the acoc wiki][wiki].

If you feel that your command is important, [open an issue on GitHub][issues] or
[mail me](mailto:eu@alexdantas.net) and it could get included on a subsequent
release!

## Bugs

* Nested regular expressions do not work well.
  Inner subexpressions need to use clustering (?:),
  not capturing ().
  In other words, they can be used for matching,
  but not for colouring.

## Author

* `acoc` was originally written by Ian Macdonald <ian@caliban.org>
  ([Homepage][ian-home]);
* It is currently being maintained by Alexandre Dantas <eu@alexdantas.net>
  ([Homepage][kure-home]);

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

* [ian-home]  : http://www.caliban.org/ruby/
* [kure-home] : http://www.alexdantas.net/
* [term]      : http://raa.ruby-lang.org/list.rhtml?name=ansicolor
* [tpty]      : http://www.tmtm.org/ruby/tpty/
* [github]    : https://github.com/alexdantas/acoc
* [issues]    : https://github.com/alexdantas/acoc/issues
* [wiki]      : https://github.com/alexdantas/acoc/wiki

