## Sets `Reply` to `T` or `F` based on the exit status of the last command.
newbool () if [ $? -ne 0 ]; then
	Reply=F
else
	Reply=T
fi

## Dumps its argument to stdout.
dump () case $1 in
	T) printf true ;;
	F) printf false ;;
	N) printf null ;;
	i*) printf %d ${1#i} ;;
	s*) printf %sx "${1#s}" | sed '
:s
$!N;$!bs
s/\\/\\\\/g;s/\t/\\t/g;s/\r/\\r/g;s/"/\\"/g;s/\n/\\n/g
s/^/"/; s/x$/"/' ;;
	a0) printf \[\] ;;
	a*) 
		printf \[
		IFS=$ARY_SEP && set -o noglob
		set -- $1 && set +o noglob && unset IFS
		shift # delte `$@` prefix

		dump "$1"; shift
		for arg; do
			printf ', '
			dump "$arg"
		done
		printf \]
		;;
	A*) eval "dump \$$1" ;;
	[fFv]*) printf '{%s}' "$1" ;;
	*) die "unknown type for dump: $1" ;;
esac

## Returns whether its arguments are equal, ie knight's `?` function
are_equal () {
	# expand out `A` references; kinda janky, should use `expandref`
	[ "${1#A}" != "$1" ] && eval "set -- \$$1 \$2"
	[ "${2#A}" != "$2" ] && eval "set -- \$1 \$$2"

	# If they're identical, then they're equal.
	[ "$1" = "$2" ] && return


	# If either element isn't an array, then they're not equal; arrays are the
	# only type which require more than a simple `=` comparison
	if [ "${1#a}" = "$1" ] || [ "${2#a}" = "$2" ]; then
		return 1
	fi

	# They're both arrays. Given how we've checked for direct equality, the only
	# things that we need to check for now are `A*`s. We also can't explode, as
	# we have two arrays to deal with. lovely :-(

	while [ -n "$1" ] && [ -n "$2" ]; do
		prefix1="${1%%"$ARY_SEP"*}"; tmp1=${1#"$prefix1"}; tmp1=${tmp1#"$ARY_SEP"}
		prefix2="${2%%"$ARY_SEP"*}"; tmp2=${2#"$prefix2"}; tmp2=${tmp2#"$ARY_SEP"}
		set -- "$tmp1" "$tmp2"

		# Hey they're the same, we're good!
		[ "$prefix1" = "$prefix2" ] && continue

		# Hm, one of them isn't a reference, looks like they're not the same
		if [ "${prefix1#A}" = "$prefix1" ] || [ "${prefix1#A}" = "$prefix1" ]; then
			return 1
		fi

		# Both are references, test them out
		are_equal "$prefix1" "$prefix2" || return
	done
}

## Sets $Reply to `-1`, `0`, or `1` depending on whether the first argument is
# smaller than, equal to or greater than the second argument.
compare () case $1 in
	s*) to_str "$2"; if [ "${1#s}" \< "$Reply" ]; then
			Reply=-1
		else
			[ "${1#s}" = "$Reply" ]
			Reply=$?
		fi ;;
	T) to_bool "$2"; Reply=$?;;
	F) to_bool "$2"; Reply=$(( - ! $? ));; # The `?` here is actually `$?`
	i*) to_int "$2"; if [ "${1#i}" -lt "$Reply" ]; then
			Reply=-1
		else
			[ "${1#i}" -eq "$Reply" ]
			Reply=$?
		fi ;;
	a*) to_ary "$2"
		set -- "$1" "$Reply"

		prefix1="${1%%"$ARY_SEP"*}"; tmp1=${1#"$prefix1"}; tmp1=${tmp1#"$ARY_SEP"}
		prefix2="${2%%"$ARY_SEP"*}"; tmp2=${2#"$prefix2"}; tmp2=${tmp2#"$ARY_SEP"}
		set -- "$tmp1" "$tmp2"

		set -- "$@" "${prefix1#a}" "${prefix2#a}"
		
		while [ -n "$1" ] && [ -n "$2" ]; do
			prefix1="${1%%"$ARY_SEP"*}"; tmp1=${1#"$prefix1"}; tmp1=${tmp1#"$ARY_SEP"}
			prefix2="${2%%"$ARY_SEP"*}"; tmp2=${2#"$prefix2"}; tmp2=${tmp2#"$ARY_SEP"}
			set -- "$tmp1" "$tmp2" "$3" "$4"
			expandref "$prefix1"; prefix1=$Reply
			expandref "$prefix2"
			compare "$prefix1" "$Reply"
			[ $Reply = 0 ] || return 0
		done
		compare i$3 i$4 ;;
	*) die "unknown type for compare: $1" ;;
esac
