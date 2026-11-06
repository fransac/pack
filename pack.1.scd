PACK(1)

# NAME

pack - manage packages

# SYNOPSIS

*pack* add [-s _repo_] [-p _prefix_] _package_ ... ++
*pack* all [-s _repo_] ++
*pack* del [-s _repo_] [-p _prefix_] [-r] _package_ ... ++
*pack* ls [-s _repo_] [-p _prefix_]

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

\-s _repo_
	Use _repo_ as the package repository. The default is "/src".
