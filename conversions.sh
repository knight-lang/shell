## Conversions to different fundamental types within Knight.

## Converts its argument to a plain string, storing the result in `$Reply`.
# (This function does not return strings with the `s` prefix.)
to_str () case $1 in
	# For strings and integers, their string repr is just themselves
	[si]*) Reply=${1#?} ;;

	# TRUE, FALSE, and NULL have literal representations
	T) Reply=true  ;;
	F) Reply=false ;;
	N) Reply=      ;;

	# Arrays need to be joined by newlines
	a*) ary_join "$NEWLINE" "$1" ;;

	# Everything else is an error (eg `BLOCK`s)
	*) die 'unknown type for to_str: %s' "$1" ;;
esac

## Converts its argument to a plain integer, storing the result in `$Reply`
# (This function does not return integers with the `i` prefix.)
to_int () case $1 in
	# Integers you just strip off the `i`
	i*) Reply=${1#i} ;;

	# TRUE, FALSE, and NULL have constant integer values
	[FN]) Reply=0 ;;
	T)    Reply=1 ;;

	# Arrays' length is the first element, after the leading `a`
	a*) Reply=${1%%$ARY_SEP*} Reply=${Reply#a} ;;

	# Strings have to be parsed, as POSIX sh doesn't have a builtin way to
	# do the c-style `atoi` string -> int conversion.
	s*)
		# Delete `s` prefix.
		Reply=${1#s}

		# Delete leading whitespace
		while tmp=${Reply#[[:space:]]}; [ "$tmp" != "$Reply" ]; do
			Reply=$tmp
		done

		# Find the sign, if one exists
		sign= ; case $(printf %c "$Reply") in
		-) sign=- Reply=${Reply#-} ;;
		+) Reply=${Reply#+} ;;
		esac

		# Strip non-integer trailing characters
		Reply=${Reply%%[!0-9]*}

		# Remove leading `0`s from the reply so it's not octal.
		while tmp=${Reply#0}; [ "$tmp" != "$Reply" ]; do
			Reply=$tmp
		done

		# If the Reply is empty, that means we stripped _all_ zeros, or
		# there were no digits to begin with. Default to zero.
		if [ -z "$Reply" ]; then
			Reply=0
		else
			# There were digits, prepend the sign!
			Reply=$sign$Reply
		fi ;;

	# Everything else is an error (eg `BLOCK`s)
	*) die 'unknown type for to_int: %s' "$1" ;;
esac

## Returns 0 if its argument is truthy
to_bool () case $1 in [sFN]|[ia]0) false; esac

## Converts its argument into a Knight array, storing the result in `$Reply`
to_ary () case $1 in
	# For arrays, it's just themselves
	a*) Reply=$1 ;;

	# For `FALSE`, `NULL`, and empty strings, they're just empty arrays
	[sFN]) Reply=a0 ;;

	# True is just an array of itself
	T) Reply=a1${ARY_SEP}T ;;

	# For integers and non-empty strings, you simply iterate over each
	# character, them into a list
	[si]*)
		prefix=$(printf %c "$1") # Get the prefix
		rest=${1#?}              # Delete the prefix

		# Handle negative numbers
		[ "${1#i-}" != "$1" ] && prefix=i- rest=${rest#?}

		# Construct the reply.
		Reply=a${#rest}$(printf '%s' "$rest" | \
			sed "s/./$ARY_SEP$prefix&/g") ;;

	# Everything else is an error (eg `BLOCK`s)
	*) die 'unknown type for to_ary: %s' "$1" ;;
esac
