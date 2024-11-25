## Sets `Reply` to `T` or `F` based on the exit status of the last command.
newbool () if [ $? -ne 0 ]; then Reply=F; else Reply=T; fi

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
		explode-array-at-arg1

		dump "$1"; shift
		for _arg; do
			printf ', '
			dump "$_arg"
		done
		printf \]
		;;
	A*) eval "dump \$$1" ;;
	[fFv]*) printf '{%s}' "$1" ;;
	*) die "unknown type for dump: $1" ;;
esac

## Returns whether its arguments are equal, ie knight's `?` function
are_equal () {
	# expand out `A` references
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
		_prefix1="${1%%"$ARY_SEP"*}"; _tmp1=${1#"$_prefix1"}; _tmp1=${_tmp1#"$ARY_SEP"}
		_prefix2="${2%%"$ARY_SEP"*}"; _tmp2=${2#"$_prefix2"}; _tmp2=${_tmp2#"$ARY_SEP"}
		set -- "$_tmp1" "$_tmp2"

		# Hey they're the same, we're good!
		[ "$_prefix1" = "$_prefix2" ] && continue

		# Hm, one of them isn't a reference, looks like they're not the same
		if [ "${_prefix1#A}" = "$_prefix1" ] || [ "${_prefix1#A}" = "$_prefix1" ]; then
			return 1
		fi

		# Both are references, test them out
		are_equal "$_prefix1" "$_prefix2" || return
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

	_prefix1="${1%%"$ARY_SEP"*}"; _tmp1=${1#"$_prefix1"}; _tmp1=${_tmp1#"$ARY_SEP"}
	_prefix2="${2%%"$ARY_SEP"*}"; _tmp2=${2#"$_prefix2"}; _tmp2=${_tmp2#"$ARY_SEP"}
	set -- "$_tmp1" "$_tmp2"

	local len1=${_prefix1#a} len2=${_prefix2#a}
	
	while [ -n "$1" ] && [ -n "$2" ]; do
		_prefix1="${1%%"$ARY_SEP"*}"; _tmp1=${1#"$_prefix1"}; _tmp1=${_tmp1#"$ARY_SEP"}
		_prefix2="${2%%"$ARY_SEP"*}"; _tmp2=${2#"$_prefix2"}; _tmp2=${_tmp2#"$ARY_SEP"}
		set -- "$_tmp1" "$_tmp2"

		compare "$_prefix1" "$_prefix2"
		[ $Reply = 0 ] || return 0
	done
	compare i$len1 i$len2 ;;
	*) die "unknown type for compare: $1" ;;
esac
