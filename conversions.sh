## Converts its argument to a plain string, storing the result in `$Reply`.
to_str () case $1 in
	# For strings and integers, their string repr is just themselves
	[si]*) Reply=${1#?} ;;

	# TRUE, FALSE, and NULL have literal representations
	T) Reply=true ;;
	F) Reply=false ;;
	N) Reply= ;;

	# Arrays need to be joined by newlines
	a*) ary_join "$NEWLINE" "$1" ;;

	# Everything else is an error (eg `BLOCK`s)
	*) die 'unknown type for to_str: %s' "$1" ;;
esac

## Converts its argument to a plain integer, storing the result in `$Reply`
to_int () case $1 in
	# Integers you just strip off the `i`
	i*) Reply=${1#i} ;;

	s*) # This is incredibly jank, and could be fixed up ;later
		set -- "${1#s}"

		# Delete leading whitespace
		while tmp=${1#[[:space:]]}; [ "$tmp" != "$1" ]; do
			set -- "$tmp"
		done

		# Find the sign
		sign=
		if tmp=${1#[-+]}; [ "$tmp" != "$1" ]; then
			sign=${1%"$tmp"}
			set -- "${1#?}"
		fi

		## Remove leading `0`s so it's not octal
		while tmp=${1#0}; [ "$tmp" != "$1" ]; do
			set -- "$tmp"
		done

		# Get the reply
		Reply=${1%%[!0-9]*}
		if [ -z "$Reply" ]; then
			Reply=0
		else
			Reply=$sign$Reply
		fi ;;

	# TRUE, FALSE, and NULL have constant integer values
	[FN]) Reply=0 ;;
	T)    Reply=1 ;;

	# Arrays' length is the first element, after the leading `a`
	a*) Reply=${1%%$ARY_SEP*} Reply=${Reply#a} ;;

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
