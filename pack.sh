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
	[ $# -ne 1 ] && exit 1

	[ ! -e "$repo/$1/depends" ] && exit 0

	while read -r l
	do
		allpackages | sed "s|^$repo/||" | grep -x "$l"
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

uninstallpackage()
{
	[ $# -ne 1 ] && exit 1

	installedpackages | sed "s|^$repo/||" | grep -qx "$1" || exit 0

	while read -r l
	do
		case "$l" in
			\/*)
				rm -rf "$prefix$l"
				;;
		esac
	done < "$repo/$1/outs"
}

# a flag.
[ $aflag -eq 1 ] && allpackages | sed "s|^$repo/||"

# l flag.
[ $lflag -eq 1 ] && installedpackages | sed "s|^$repo/||"

# u flag.
[ $uflag -eq 1 ] && uninstallpackage "$1"
