## Arrays are represented as a single string, in the following format:
#
#     a<ary_length>${ARY_SEP}element 1${ARY_SEP}element 2...
#
# Note that `$ARY_SEP` is a single character that's not within Knight's required
# character set (and thus is safe to use a deliminator). It also isn't the same
# as any of the other deliminators.
#
# Nested arrays are represented via `A<IDX>`, so that any `$ARY_SEP`s they might
# have won't conflict. The original value is reachable by `eval`ing the
# reference (ie `eval "orig_ary=\$$reference"` gives you the reference). We
# ensure that no normal variables in the program start with `A<DIGIT>`, so these
# references are safe to eval. 
#
# Most code doesn't need to worry about references; They're only a problem when
# individual elements of an array are being examined, such as via `[` or `^`.
# These are handled via `expandref`, which expands out array references.
#
# The empty array is `a0`
##

## The next array reference number. Incremented via `new_ary`
Next_Ary_Ref_Idx=0

## Creates a new array from its arguments, putting its result in `$Reply`.
new_ary () {
	Reply=a$#

	for arg
	do
		# If an argument is a non-empty array, then create a reference
		# for it and update `arg`.
		if [ "${arg#a}" != "$arg" ] && ! [ "$arg" = a0 ]; then
			eval "A$((Next_Ary_Ref_Idx += 1))=\$arg"
			arg=A$Next_Ary_Ref_Idx
		fi

		# Add the element to the end of the `$Reply` array.
		Reply=$Reply$ARY_SEP$arg
	done
}

## Expands out array references, putting the result in `$Reply`.
expandref () if [ "${1#A}" = "$1" ]; then
	Reply=$1
else
	eval "Reply=\$$1"
fi

## Concatenates a knight array (argument 2) by a string (argument 1), placing
# the result in `$Reply`.
ary_join () {
	# If the array is empty, just return nothing
	if [ "$2" = a0 ]; then
		Reply=
		return
	fi

	# This keeps track of local variables in $@, as `ary_join` might end up
	# recursively calling itself (and clobbering previous values):
	#   - $1 is the separator
	#   - $2 is the elements remaining in the array
	#   - $3 is the return value
	set -- "$1" "${2#*$ARY_SEP}$ARY_SEP" ''

	# While there's still something left to join, keep joining
	while [ -n "$2" ]; do
		# Expands the first out if it's an array, else keep it the same.
		expandref "${2%%$ARY_SEP*}"

		# Convert the expanded element
		to_str "$Reply"

		# Update the list of arguments
		set -- "$1" "${2#*ARY_SEP}" "$3$1$Reply"	
	done

	# Since we had an extra `$ARY_SEP` when setting up the args, we need to
	# remove the resulting separator
	Reply=${3#"$1"}
}
