PACK(1)

# NAME

pack - manage packages

# SYNOPSIS

*pack* -a [-s _repo_] ++
*pack* -i [-s _repo_] [-p _prefix_] _package_ ... ++
*pack* -l [-s _repo_] [-p _prefix_] ++
*pack* -u [-s _repo_] [-p _prefix_] [-r] _package_ ...

# DESCRIPTION

*pack* is a package manager.

# OPTIONS

\-a
	List all packages.

\-i
	Install _package_ and its runtime dependencies.

\-l
	List installed packages.

\-p _prefix_
	Use _prefix_ as the prefix directory. The default  is ""; that is, root.

\-r
	Also uninstall the runtime dependencies of _package_.

\-s _repo_
	Use _repo_ as the package repository. The default is "/src".

\-u
	Uninstall _package_.
