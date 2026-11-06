#!/bin/sh
set -eu

program=$(basename "$0")

error()
{
	printf '%s\n' "$1" >&2
	exit 1
}

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

aflag=0
iflag=0
lflag=0
pflag=0
rflag=0
sflag=0
uflag=0

prefix=''
repo='/src'

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

# Utilities.
allpackages()
{
	for d in $(find "$repo"/* -type d)
	do
		[ -d "$d" ] && [ -f "$d/outs" ] \
		            && [ -f "$d/build" ] \
		            && printf '%s\n' "$d"
	done
}

packagedependencies()
{
	[ $# -ne 1 ] && return 1

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

		if allpackages | sed "s|^$repo/||" | grep -qx "$p"
		then
			printf '%s\t%s\n' "$l" "$runtime"
		fi
	done < "$repo/$1/depends"
}

installedpackages()
{
	for p in $(allpackages)
	do
		notinst=0

		while read -r l
		do
			[ $notinst -eq 1 ] && break

			case "$l" in
				\/*)
					[ ! -e "$prefix$l" ] && notinst=1
					;;
			esac
		done < "$p/outs"

		[ $notinst -eq 0 ] && printf '%s\n' "$p"
	done
}

installpackage()
{
	[ $# -ne 2 ] && return 1

	installedpackages | sed "s|^$repo/||" | grep -qx "$1" && return 0

	tmp=$(mktemp -dt 'packXXXXXX')
	chmod 700 "$tmp"

	# Install non-runtime packages to tmp.
	for p in $(packagedependencies "$1" | grep '\t0' | cut -f 1)
	do
		installpackage "$p" "$tmp"
	done

	echo "Installing $1 to $2/."

	{
		mkdir -p "$tmp/src"
		cp "$repo/$1/build" "$tmp/src"
		chmod 700 "$tmp/src/build"

		# Copy sources.
		[ -e "$repo/$1/sources" ] && while read -r l
		do
			sha256=$(printf '%s\n' "$l"  | cut -f 1)
			url=$(printf '%s\n' "$l"     | cut -f 2)
			relpath=$(printf '%s\n' "$l" | cut -f 3)

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
					;;
				*)
					if [ -n "$relpath" ]
					then
						target="$tmp/src/$relpath"
					else
						target="$tmp/src/$url"
					fi

					cp "$repo/$1/$url" "$target"
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
			cd "$tmp/src"
			./build
		else
			chroot "$tmp" /src/build
		fi

		# Install.
		while read -r l
		do
			case "$l" in
				\/*)
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

	# Install runtime packages.
	for p in $(packagedependencies "$1" | grep '\t1' | cut -f 1)
	do
		installpackage "$p" "$2"
	done
}

uninstallpackage()
{
	[ $# -ne 2 ] && return 1

	installedpackages | sed "s|^$repo/||" | grep -qx "$1" || return 0

	echo "Uninstalling $p."

	while read -r l
	do
		case "$l" in
			\/*)
				rm -rf "$prefix$l"
				;;
		esac
	done < "$repo/$1/outs"

	if [ "$2" -eq 1 ]
	then
		for p in $(packagedependencies "$1" | grep '\t1' | cut -f 1)
		do
			uninstallpackage "$p" 1
		done
	fi
}

# a flag.
[ $aflag -eq 1 ] && allpackages | sed "s|^$repo/||"

# l flag.
[ $lflag -eq 1 ] && installedpackages | sed "s|^$repo/||"

# u flag.
[ $uflag -eq 1 ] && uninstallpackage "$1" $rflag

# i flag.
[ $iflag -eq 1 ] && installpackage "$1" "$prefix"
