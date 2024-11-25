## Arrays are represented as a single string, in the following format:
#     a<ary_length>${ARY_SEP}element 1${ARY_SEP}element 2...
# Note that `$ARY_SEP` is a single character that's not within Knight's required
# character set (and thus is safe to use a deliminator). It also isn't the same
# as any of the other deliminators.
#
# Nested arrays are represented via `A<IDX>`, so that any `$ARY_SEP`s they might
# have won't conflict. The original value is reachable by `eval`ing the
# reference (ie `eval "orig_ary=\$$reference"` gives you the reference). We
# ensure that no normal variables in the program start with `A<DIGIT>`, so these
# references are safe to use. 
#
# Most functions don't need to worry about references, but some (such as `[`) d
# do, and handle them accordingly.
#
# The empty array is `a0`
##

## The next array reference number. Incremented via `new_ary`
Next_Ary_Ref_Idx=0

## Creates a new array from its arguments, putting its result in `$Reply`.
new_ary () {
	Reply=a$#

	for _arg; do
		# If an argument is a non-empty array, then create a reference for it and
		# update `_arg`.
		if [ "${_arg#a}" != "$_arg" ] && ! [ "$_arg" = a0 ]; then
			eval "A$((Next_Ary_Ref_Idx += 1))=\$_arg"
			_arg=A$Next_Ary_Ref_Idx
		fi

		# Add the element to the end of the `$Reply` array.
		Reply=$Reply$ARY_SEP$_arg
	done
}

## Expands out array references, putting the result in `$Reply`.
expandref () if [ "${1#A}" = "$1" ]; then
	Reply=$1
else
	eval "Reply=\$$1"
fi

ary_join () {
	# We have to have `result` be local because `to_str` will clobber `Reply`.
	local sep=$1 result=
	shift

	IFS=$ARY_SEP && set -o noglob
	set -- $1 && set +o noglob && unset IFS

	shift # delete `aLEN` prefix

	for _arg; do
		to_str "$_arg"
		result=$result${result:+$sep}$Reply
	done

	Reply=$result
}
