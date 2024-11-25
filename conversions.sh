## Converts its argument to a string, storing the result in $Reply
to_str () case $1 in
	[si]*) Reply=${1#?} ;;
	T)     Reply=true ;;
	F)     Reply=false ;;
	N)     Reply= ;;
	A*)    eval "to_str \$$1" ;;
	a*)    ary_join "$NEWLINE" "$1" ;;
	[fFv]*) run "$1"; to_str "$Reply" ;;
	*) die "unknown type for to_str: $1" ;;
esac

## Converts its argument to an integer, storing the result in $Reply
to_int () case $1 in
	s*) # TODO LOL
		Reply=$(perl -e 'print 0+$ARGV[0];' -- "${1#s}") ;;
# case ${1#s} in
# 		-*[!0-9]*) TODO ;;
# 		[!-]*[!0-9]*) TODO ;;
# 		*) Reply=${1#s} ;; # TODO: there's no way this works
		# esac ;;
	[FN]) Reply=0 ;;
	T)    Reply=1 ;;
	i*)   Reply=${1#i} ;;
	A*)   eval "to_int \$$1" ;;
	a*)   Reply=${1#a}
	      Reply=${Reply%%"$ARY_SEP"*} ;;
	[fFv]*) run "$1"; to_int "$Reply" ;;
	*) die "unknown type for to_int: $1" ;;
esac

## Returns 0 if its argument is truthy
to_bool () case $1 in [sFN]|[ia]0) false;; [fFv]*) run "$1"; to_bool "$Reply"; esac

# Converts its argument to an array, storing the result in $Reply
to_ary () case $1 in
	[sFN]) Reply=a0 ;; # Note that we handle the empty string case here
	T) Reply=a1:T ;;
	[si]*) _str=${1#?}
		_kind=$(printf %c "$1")
		if [ "${1#i-}" != "$1" ]; then
			_kind=i-
			_str=${_str#?}
		fi
		Reply=a${#_str}
		while [ -n "$_str" ]; do
			Reply=$Reply${ARY_SEP}$_kind$(printf %c "$_str")
			_str=${_str#?}
		done ;;
	A*)    eval "to_ary \$$1" ;;
	a*)    Reply=$1 ;;
	[fFv]*) run "$1"; to_ary "$Reply" ;;
	*) die "unknown type for $to_ary: $1" ;;
esac
