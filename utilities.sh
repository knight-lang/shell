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
	# TRUE, FALSE, and NULL have literal messages
	T) printf true  ;;
	F) printf false ;;
	N) printf null  ;;

	# Integers: you just delete the `i` prefix
	i*) printf %d ${1#i} ;;

	# For strings, you need to go through `sed` to do the replacements.
	s*) printf %sx "${1#s}" | sed '
# Collect all input lines into the pattern space so we can delete the newline.
:s
$!N
$!bs
# At this point, the entire input is in the pattern space, so we can now parse
# it all out.

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

	# Handle arrays
	a*)
		printf '['
		IFS=$ARY_SEP; set -- $1; unset IFS
		shift # delete `a#` prefix

		if [ $# -ne 0 ]; then
			dump "$1"; shift
			for arg; do
				printf ', '
				dump "$arg"
			done
		fi
		printf ']' ;;

	# For every other type just print it with `{}` around it.
	*) printf '{%s}' "$1" ;;
esac

## Returns whether its arguments are equal, ie knight's `?` function
are_equal () {
	# If they're identical, then they're equal.
	[ "$1" = "$2" ] && return

	# If either element isn't an array, then they're not equal; arrays are
	# the only type which require more than a simple `=` comparison
	if [ "${1#a}" = "$1" ] || [ "${2#a}" = "$2" ]; then
		return 1
	fi

	# Make sure the lengths of the arrays are the same; if they aren't, then
	# there's no way they're equal.
	left_len=${1%%$ARY_SEP*} left_len=${left_len#a}
	right_len=${2%%$ARY_SEP*} right_len=${right_len#a}
	[ "$left_len" -ne "$right_len" ] && return 1

	# Strip out the length prefixes. This is technically redundant, as they
	# will always be equal (as we checked for their equality in the previous
	# line), but it'll save a recursive function call.
	set -- "${1#$ARY_SEP*}" "${2#$ARY_SEP*}"

	# Check each element at a time, seeing if they're equal, returning at
	# the first non-equal comparison. (We only check for `-n "$1"` because
	# they both have the same length, so there's no need to do two `-n`s.)
	while [ -n "$1" ]; do
		# Fetch the first elements out of the arrays
		left=${1%%$ARY_SEP*} tmp1=${1#"$left"} tmp1=${tmp1#$ARY_SEP}
		right="${2%%$ARY_SEP*}" tmp2=${2#"$right"} tmp2=${tmp2#$ARY_SEP}

		# Remove the elements from the arrays
		set -- "$tmp1" "$tmp2"

		# Expand out array references if we have any
		expandref "$left"; left=$Reply
		expandref "$right" # Note `expandref` won't clobber `$left`

		# Check to see if they're the same, returning if they arent
		are_equal "$left" "$Reply" || return
	done

	# `while` will return `0` when its done, so no need to explicitly return
	# here.
}

## Sets `$Reply` to a negative, zero, or positive integer depending on whether
# the first argument is smaller than, equal to or greater than the second.
compare () case $1 in
	# Compare strings. According to POSIX, `[` doesn't need to support
	# lexicographical string comparisons; the correct way to do it is via
	# `expr`'s `<` operator, with a noninteger character prepended to ensure
	# that they won't be treated as integers.
	s*)
		# TODO: how does `LC_ALL` and co factor into this?
		if to_str "$2"; expr "a${1#s}" \< "a$Reply" >/dev/null; then
			Reply=-1
		else
			[ "${1#s}" = "$Reply" ]
			Reply=$? # Abuse the fact that `[`'s returns `1` or `0`.
		fi ;;

	# Compare integers; unlike strings, we can use `[` as it supports ints.
	i*) 	if to_int "$2"; [ ${1#i} -lt $Reply ]; then
			Reply=-1
		else
			Reply=$((${1#i} != Reply))
		fi ;;

	# TRUE and FALSE comparisons; we can actually use the return value from
	# `to_bool "$2"` to determine the comparisons.
	T) to_bool "$2"; Reply=$?;;
	F) to_bool "$2"; Reply=$(( - (! $?) ));;
	a*)
		# Compare arrays. this is a bit janky tbh, and could be made
		# much clearer
		to_ary "$2"
		set -- "$1" "$Reply"

		prefix1="${1%%$ARY_SEP*}" tmp1=${1#"$prefix1"} \
			tmp1=${tmp1#$ARY_SEP}
		prefix2="${2%%$ARY_SEP*}" tmp2=${2#"$prefix2"} \
			tmp2=${tmp2#$ARY_SEP}
		set -- "$tmp1" "$tmp2"

		set -- "$@" "${prefix1#a}" "${prefix2#a}"
		
		while [ -n "$1" ] && [ -n "$2" ]; do
			prefix1="${1%%$ARY_SEP*}" tmp1=${1#"$prefix1"} \
				tmp1=${tmp1#$ARY_SEP}
			prefix2="${2%%$ARY_SEP*}" tmp2=${2#"$prefix2"} \
				tmp2=${tmp2#$ARY_SEP}

			set -- "$tmp1" "$tmp2" "$3" "$4"
			expandref "$prefix1"; prefix1=$Reply
			expandref "$prefix2"
			compare "$prefix1" "$Reply"
			[ $Reply = 0 ] || return 0
		done
		compare i$3 i$4 ;;

	# Every type is invalid for `compare`
	*) die 'unknown type for compare: %s' "$1" ;;
esac
