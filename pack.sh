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

# Prints message $1 and fails.
error()
{
	printf '%s\n' "$1" >&2
	return 1
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
		if allpackages | sed "s|^$repo/||" | grep -qx "$p"
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
	installedpackages "$2" | sed "s|^$repo/||" | grep -qx "$1" && return 0

	tmp=$(mktemp -dt 'packXXXXXX')
	chmod 700 "$tmp"

	# Install non-runtime packages to tmp.
	for p in $(packagedependencies "$1" | grep '\t0' | cut -f 1)
	do
		installpackage "$p" "$tmp"
	done

	echo "Installing $1 to $2/."

	{
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

					echo "Downloading $url."

					curl -sL "$url" > "$target"

					if [ $? -ne 0 ]
					then
						error "Failed to download $url."
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

					[ -f "$src" ] \
					|| error "Non-existent source file $src."

					cp "$src" "$target"
					;;
			esac

			chmod 600 "$target"

			if ! printf '%s %s\n' "$sha256" "$target" \
			   | sha256sum -c > /dev/null
			then
				expected=$(sha256sum "$target" | cut -d ' ' -f 1)

				error $({
					echo "Hash of $url does not match."
					echo "Expected: $expected"
					echo "Got:      $sha256"
				})
			fi
		done < "$repo/$1/sources"

		# Build.
		if head -n 1 "$repo/$1/outs" | grep -qx '#no-chroot'
		then
			cd "$tmp"
			./src/build
		else
			chroot "$tmp" /src/build
		fi

		# Install.
		while read -r l
		do
			case "$l" in
				\/*)
					[ ! -e "$tmp$l" ] \
					|| error "Out file $l was not build."

					mkdir -p "$(dirname "$2$l")"
					cp -rf "$tmp$l" "$2$l"
					;;
			esac
		done < "$repo/$1/outs"
	} || {
		rm -rf "$tmp"
		return 1
	}

	rm -rf "$tmp"

	# Install runtime packages. On error, uninstall the dependant package
	# and all of the others runtime dependencies, which could have been
	# already installed.
	for p in $(packagedependencies "$1" | grep '\t1' | cut -f 1)
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
	installedpackages "$2" | sed "s|^$repo/||" | grep -qx "$1" || return 0

	# If at least one installed package runtime-depends on this one, do not
	# uninstall.
	for p in $(installedpackages "$2" | sed "s|^$repo/||")
	do
		if [ -n "$(packagedependencies "$p" | grep '$1\t1')" ]
		then
			echo "Not uninstalling $1 since $p depends on it."
			return 0
		fi
	done

	echo "Uninstalling $p."

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
		for p in $(packagedependencies "$1" | grep '\t1' | cut -f 1)
		do
			uninstallpackage "$p" "$2" 1
		done
	fi
}

# Errors the synopsis of the program.
usage()
{
	u=$({
		echo "Usage: $program -a [-s repo]"
		echo "       $program -i [-s repo] [-p prefix] package ..."
		echo "       $program -l [-s repo] [-p prefix]"
		echo "       $program -u [-s repo] [-p prefix] [-r] package ..."
	})
	error "$u"
}

# Flags.
aflag=0
iflag=0
lflag=0
pflag=0
rflag=0
sflag=0
uflag=0

# Arguments.
prefix=''
repo='/src'

# Command parsing.
while getopts "ailp:rs:u" o 2> /dev/null
do
	case "$o" in
	a) aflag=1 ;;
	i) iflag=1 ;;
	l) lflag=1 ;;
	p)
		pflag=1
		prefix="$OPTARG"
		;;
	r) rflag=1 ;;
	s)
		sflag=1
		repo="$OPTARG"
		;;
	u) uflag=1 ;;
	*) usage ;;
	esac
done
shift $((OPTIND - 1))

# Check arguments.
[ $((aflag + iflag + lflag + uflag)) -ne 1 ] && usage
[ $((aflag + pflag)) -gt 1 ] && usage
[ $rflag -eq 1 ] && [ $uflag -eq 0 ] && usage
[ $# -gt 0 ] && [ $iflag -eq 0 ] && [ $uflag -eq 0 ] && usage
[ $# -eq 0 ] && [ $((iflag + uflag)) -eq 1 ] && usage

# a flag.
[ $aflag -eq 1 ] && allpackages | sed "s|^$repo/||"

# l flag.
[ $lflag -eq 1 ] && installedpackages "$prefix" | sed "s|^$repo/||"

# u flag.
[ $uflag -eq 1 ] && uninstallpackage "$1" "$prefix" $rflag

# i flag.
[ $iflag -eq 1 ] && installpackage "$1" "$prefix"
