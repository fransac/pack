PACK(1)

# NAME

pack - manage packages

# SYNOPSIS

*pack* all ++
*pack* [-p _prefix_] ls ++
*pack* [-p _prefix_] add [_package_ ...] ++
*pack* [-p _prefix_] [-r] del [_package_ ...]

# DESCRIPTION

*pack* is a package manager.

# COMMANDS

add
	Install _package_ and its runtime dependencies.

all
	List all packages.

del
	Uninstall _package_.

ls
	List installed packages.

# OPTIONS

\-p _prefix_
	Use _prefix_ as the prefix directory. The default  is ""; that is, root.

\-r
	Also uninstall the runtime dependencies of _package_.

# ENVIRONMENT

_PACK_REPOSITORY_
	The package repository. If unset, "/src" is used.
