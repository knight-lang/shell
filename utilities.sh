## Print out a message and exit the program
die () {
	fmt="%s: $1\\n"
	shift
	printf "$fmt" "$SCRIPT_NAME" "$@"
	exit 2
}

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
# Collect all input lines into the pattern space so we can delete the newline.
:s
$!N
$!bs

# Do the required escapes.
s/\\/\\\\/g
s/\t/\\t/g
s/\r/\\r/g
s/"/\\"/g
s/\n/\\n/g

# Add a " at the start of the input
s/^/"/

# Add a " at the end of the input, and delete the "x". (The "x" is added so that
# the last character of the input is not a newline, as that is hard to handle.)
s/x$/"/' ;;
	a0) printf '[]' ;;
	a*) 
		printf '['
		IFS=$ARY_SEP; set -- $1; unset IFS;
		shift # delete `$@` prefix

		dump "$1"; shift
		for arg; do
			printf ', '
			dump "$arg"
		done
		printf ']'
		;;
	A*) eval "dump \$$1" ;;
	[fFv]*) printf '{%s}' "$1" ;;
	*) die "unknown type for dump: $1" ;;
esac

## Returns whether its arguments are equal, ie knight's `?` function
are_equal () {
	# Expand out prefixes
	expandref "$1"; set -- "$Reply" "$2"
	expandref "$2"; set -- "$1" "$Reply"

	# If they're identical, then they're equal.
	[ "$1" = "$2" ] && return

	# If either element isn't an array, then they're not equal; arrays are
	# the only type which require more than a simple `=` comparison
	if [ "${1#a}" = "$1" ] || [ "${2#a}" = "$2" ]; then
		return 1
	fi

	left_len=${1%%$ARY_SEP*} left_len=${left_len#a}
	right_len=${2%%$ARY_SEP*} right_len=${right_len#a}

	[ "$left_len" -ne "$right_len" ] && return 1

	tmp1=${1#$ARY_SEP*}
	tmp2=${2#$ARY_SEP*}
	set -- "$tmp1" "$tmp2"

	# They're both arrays. Given how we've checked for direct equality, the
	# only things that we need to check for now are `A*`s. We also can't
	# `set -- $1``, as we have two arrays to deal with. lovely :-(
	while [ -n "$1" ] && [ -n "$2" ]; do
		# Fetch the first elements out of the arrays
		left="${1%%$ARY_SEP*}"
		tmp1=${1#"$left"}
		tmp1=${tmp1#$ARY_SEP}

		right="${2%%$ARY_SEP*}"
		tmp2=${2#"$right"}
		tmp2=${tmp2#$ARY_SEP}

		# Remove the elements from the arrays
		set -- "$tmp1" "$tmp2"

		# Check to see if they're the same
		are_equal "$left" "$right" || return
	done
}

## Sets $Reply to `-1`, `0`, or `1` depending on whether the first argument is
# smaller than, equal to or greater than the second argument.
compare () case $1 in
	s*)
		if to_str "$2"; [ "${1#s}" \< "$Reply" ]
		then Reply=-1
		else [ "${1#s}" = "$Reply" ];  Reply=$?
		fi ;;
	i*) 	if to_int "$2"; [ "${1#i}" -lt "$Reply" ]
		then Reply=-1
		else [ "${1#i}" -eq "$Reply" ]; Reply=$?
		fi ;;
	T) to_bool "$2"; Reply=$?;;
	F) to_bool "$2"; Reply=$(( - (! $?) ));;
	a*)
		to_ary "$2"
		set -- "$1" "$Reply"

		prefix1="${1%%$ARY_SEP*}" tmp1=${1#"$prefix1"} tmp1=${tmp1#$ARY_SEP}
		prefix2="${2%%$ARY_SEP*}" tmp2=${2#"$prefix2"} tmp2=${tmp2#$ARY_SEP}
		set -- "$tmp1" "$tmp2"

		set -- "$@" "${prefix1#a}" "${prefix2#a}"
		
		while [ -n "$1" ] && [ -n "$2" ]; do
			prefix1="${1%%$ARY_SEP*}" tmp1=${1#"$prefix1"} tmp1=${tmp1#$ARY_SEP}
			prefix2="${2%%$ARY_SEP*}" tmp2=${2#"$prefix2"} tmp2=${tmp2#$ARY_SEP}
			set -- "$tmp1" "$tmp2" "$3" "$4"
			expandref "$prefix1"; prefix1=$Reply
			expandref "$prefix2"
			compare "$prefix1" "$Reply"
			[ $Reply = 0 ] || return 0
		done
		compare i$3 i$4 ;;
	*) die 'unknown type for compare: %s' "$1" ;;
esac
