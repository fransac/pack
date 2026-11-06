#!/bin/sh
set -eu

program=$(basename "$0")

# Returns a newline-separated list of all packages.
allpackages()
{
	for d in $(find "$repo"/* -type d)
	do
		[ -d "$d" ] && [ -f "$d/outs" ] \
		            && [ -f "$d/build" ] \
		            && printf '%s\n' "$d"
	done
}

# Prints message $1 to stderr, prefixing it with the program name.
log()
{
	printf '%s: %s\n' "$program" "$1" >&2
}

# Returns a multi-line tab-separated list, where each line is a dependency of $1.
# The first column is the name of each dependency; the second column is 1 if the
# dependency is runtime, or 0 otherwise.
packagedependencies()
{
	[ $# -ne 1 ] && return 1

	# If the depends file does not exist, the package has no dependency.
	[ ! -f "$repo/$1/depends" ] && return 0

	while read -r l
	do
		p=$(printf '%s\n' "$l" | cut -f 1)
		r=$(printf '%s\n' "$l" | cut -f 2)

		if [ "$r" == 'runtime' ]
		then
			runtime=1
		else
			runtime=0
		fi

		# Only print the instances that represent actual existing
		# packages.
		if allpackages | sed "s|^$repo/||" | grep -q "^$p\$"
		then
			printf '%s\t%s\n' "$l" "$runtime"
		fi
	done < "$repo/$1/depends"
}

# Returns a newline-separated list of packages installed in $1.
installedpackages()
{
	[ $# -ne 1 ] && return 1

	for p in $(allpackages)
	do
		notinst=0
		while read -r l
		do
			case "$l" in
				\/*)
					[ ! -e "$1$l" ] && notinst=1 && break
					;;
			esac
		done < "$p/outs"
		[ $notinst -eq 0 ] && printf '%s\n' "$p"
	done
}

# Installs package $1 and its runtime dependencies in $2.
installpackage()
{
	[ $# -ne 2 ] && return 1

	# Skip if already installed.
	installedpackages "$2" | sed "s|^$repo/||" | grep -q "^$1\$" && return 0

	tmp=$(mktemp -dt 'packXXXXXX')
	chmod 700 "$tmp"

	# Install non-runtime packages to tmp.
	for p in $(packagedependencies "$1" | grep '\t0$' | cut -f 1)
	do
		installpackage "$p" "$tmp"
	done

	log "Installing $1 to $2/."

	{
		fail=0

		# Copy build.
		mkdir -p "$tmp/src"
		cp "$repo/$1/build" "$tmp/src"
		chmod 700 "$tmp/src/build"

		# Copy sources.
		[ -e "$repo/$1/sources" ] && while read -r l
		do
			sha256=$(printf '%s\n' "$l"  | cut -f 1)
			url=$(printf '%s\n' "$l"     | cut -f 2)
			relpath=$(printf '%s\n' "$l" | cut -f 3)

			# The URL field is mandatory.
			[ -z "$url" ] && continue

			case "$url" in
				http://*|https://*|ftp://*|ftps://*)
					if [ -n "$relpath" ]
					then
						target="$tmp/src/$relpath"
					else
						urlbn=$(basename "$url")
						target="$tmp/src/$urlbn"
					fi

					log "Downloading $url."

					curl -sL "$url" > "$target"

					if [ $? -ne 0 ]
					then
						log "Failed to download $url."
						fail=1
						break
					fi
					;;
				..*)
					# Do not access parent directories.
					;;
				*)
					if [ -n "$relpath" ]
					then
						target="$tmp/src/$relpath"
					else
						target="$tmp/src/$url"
					fi

					src="$repo/$1/$url"

					if [ ! -f "$src" ]
					then
						log "Source file $src does not exist."
						fail=1
						break
					fi

					cp "$src" "$target"
					;;
			esac

			chmod 600 "$target"

			if ! printf '%s %s\n' "$sha256" "$target" \
			   | sha256sum -c > /dev/null
			then
				expected=$(sha256sum "$target" | cut -d ' ' -f 1)

				log "Hash of $url does not match."
				log "Expected: $expected"
				log "Got:      $sha256"
				fail=1
				break
			fi
		done < "$repo/$1/sources"

		# Build if not failed.
		if [ $fail -eq 0 ] \
		&& head -n 1 "$repo/$1/outs" | grep -q '^#no-chroot$'
		then
			log "Package $1 won't chroot."
			printf '(y) ' >&2
			read -r y
			if [ "$y" != 'y' ]
			then
				fail=1
			else
				cd "$tmp"
				PREFIX="$2" ./src/build
			fi
		else
			chroot "$tmp" /src/build
		fi

		# Install if not failed.
		[ $fail -eq 0 ] && while read -r l
		do
			case "$l" in
				\/*)
					if [ ! -e "$tmp$l" ]
					then
						log "Out file $l was not built."
						fail=1
						break
					else
						mkdir -p "$(dirname "$2$l")"
						cp -rf "$tmp$l" "$2$l"
					fi
					;;
			esac
		done < "$repo/$1/outs"

		# If flagged, fail.
		[ $fail -eq 0 ]
	} || {
		rm -rf "$tmp"
		return 1
	}

	rm -rf "$tmp"

	# Install runtime packages. On fail, uninstall the dependant package
	# and all of the others runtime dependencies, which could have been
	# already installed.
	for p in $(packagedependencies "$1" | grep '\t1$' | cut -f 1)
	do
		installpackage "$p" "$2"
	done || uninstallpackage "$1" "$2" 1
}

# Uninstalls package $1 from $2, if none of the other installed packages depend on
# it. If $3 is 1, the runtime dependencies of $1 are also uninstalled from $2.
uninstallpackage()
{
	[ $# -ne 3 ] && return 1

	# Skip if not installed.
	installedpackages "$2" | sed "s|^$repo/||" | grep -q "^$1\$" || return 0

	# If at least one installed package runtime-depends on this one, do not
	# uninstall.
	for p in $(installedpackages "$2" | sed "s|^$repo/||")
	do
		rdeps=$(packagedependencies "$p" | grep "^$1\t1\$")
		if [ -n "$rdeps" ]
		then
			log "Not uninstalling $1 since $p depends on it."
			return 0
		fi
	done

	log "Uninstalling $1."

	while read -r l
	do
		case "$l" in
			\/*)
				rm -rf "$2$l"
				;;
		esac
	done < "$repo/$1/outs"

	# Recursive.
	if [ "$3" -eq 1 ]
	then
		for p in $(packagedependencies "$1" | grep '\t1$' | cut -f 1)
		do
			uninstallpackage "$p" "$2" 1
		done
	fi
}

# Fails after printing the synopsis of the program to stderr.
usage()
{
	echo "Usage: $program add [-s repo] [-p prefix] package ..." >&2
	echo "       $program all [-s repo]" >&2
	echo "       $program del [-s repo] [-p prefix] [-r] package ..." >&2
	echo "       $program ls [-s repo] [-p prefix]" >&2
	return 1
}

# Commands.
addcmd=0
allcmd=0
delcmd=0
lscmd=0

# Flags.
pflag=0
rflag=0
sflag=0

# Arguments.
prefix=''
repo='/src'

# Flag parsing.
while getopts "p:rs:" o 2> /dev/null
do
	case "$o" in
	p)
		pflag=1
		prefix="$OPTARG"
		;;
	r) rflag=1 ;;
	s)
		sflag=1
		repo="$OPTARG"
		;;
	*) usage ;;
	esac
done
shift $((OPTIND - 1))

# Command parsing.
[ $# -eq 0 ] && usage
case "$1" in
	add)
		addcmd=1
		;;
	all)
		allcmd=1
		;;
	del)
		delcmd=1
		;;
	ls)
		lscmd=1
		;;
	*)
		usage
		;;
esac
shift 1

# Check arguments.
[ $((addcmd + pflag)) -gt 1 ] && usage
[ $# -gt 0 ] && [ $addcmd -eq 0 ] && [ $delcmd -eq 0 ] && usage
[ $rflag -eq 1 ] && [ $delcmd -eq 0 ] && usage
[ $# -eq 0 ] && [ $((addcmd + delcmd )) -eq 1 ] && usage

# Add command.
[ $addcmd -eq 1 ] && installpackage "$1" "$prefix"

# All command.
[ $allcmd -eq 1 ] && allpackages | sed "s|^$repo/||"

# Del command.
[ $delcmd -eq 1 ] && uninstallpackage "$1" "$prefix" $rflag

# Ls command.
[ $lscmd -eq 1 ] && installedpackages "$prefix" | sed "s|^$repo/||"
