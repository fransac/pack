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

a=0
i=0
l=0
p=0
r=0
s=0
u=0

prefix='/'
repo='/src'

while getopts "ailp:rs:u" o 2> /dev/null
do
	case "$o" in
	a) a=1 ;;
	i) i=1 ;;
	l) l=1 ;;
	p)
		p=1
		prefix="$OPTARG"
		;;
	r) r=1 ;;
	s)
		s=1
		repo="$OPTARG"
		;;
	u) u=1 ;;
	*) usage ;;
	esac
done

shift $((OPTIND - 1))

# Check arguments.
[ $((a + i + l + u)) -ne 1 ] && usage
[ $((a + p)) -gt 1 ] && usage
[ $r -eq 1 ] && [ $u -eq 0 ] && usage
[ $# -gt 0 ] && [ $i -eq 0 ] && [ $u -eq 0 ] && usage
[ $# -eq 0 ] && [ $((i + u)) -eq 1 ] && usage

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

# a flag.
[ $a -eq 1 ] && allpackages | sed "s|^$repo/||"
