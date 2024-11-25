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
	*) die "unknown type for to_str: $1" ;;
esac

## Converts its argument to a plain integer, storing the result in `$Reply`
to_int () case $1 in
	# Integers you just strip off the `i`
	i*) Reply=${1#i} ;;

	s*) # TODO LOL
		Reply=$(perl -e 'print 0+$ARGV[0];' -- "${1#s}") ;;

	# TRUE, FALSE, and NULL have constant ints
	[FN]) Reply=0 ;;
	T)    Reply=1 ;;

	# Arrays' length is the first element, after the leading `a`
	a*) Reply=${1#a} Reply=${Reply%%"$ARY_SEP"*} ;;

	# Everything else is an error (eg `BLOCK`s)
	*) die "unknown type for to_int: $1" ;;
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
	T) Reply=a1:T ;;

	# For integers and non-empty strings, you simply iterate over each character,
	# putting theminto a list
	[si]*)
		_prefix=$(printf %c "$1") # Get the prefix
		_rest=${1#?}              # Delete the prefix

		# Handle negative numbers
		if [ "${1#i-}" != "$1" ]; then _prefix=i-; _rest=${_rest#?}; fi

		# Construct the reply.
		Reply=a${#_rest}$(printf '%s' "$_rest" | sed "s/./$ARY_SEP$_prefix&/g") ;;

	# Everything else is an error (eg `BLOCK`s)
	*) die "unknown type for $to_ary: $1" ;;
esac
