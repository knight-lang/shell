## Evaluates the first arg as a knight program, putting the result in $Reply.
eval_kn () {
	# TODO: `exec` with no args to make this a builtin?
	if [ $# = 0 ]; then
		next_expr
	else
		next_expr <<EOS
$1
EOS
	fi || die 'no program given'
	run "$Reply"
}


readonly UNIQ_SEP=\`
run () {
	case $1 in
		v*) eval "run \$$1"; return ;; # `set -o nounset` will fail if the var isnt valid
		F?*) eval "run \"\$$1\""; return ;;
		[!f]*) Reply="$1"; return ;;
	esac

	# Explode the arguments
	_old_IFS=$IFS; IFS=$FN_SEP && set -o noglob
	set -- $1 && IFS=$_old_IFS && set +o noglob

	local fn=${1#f}; shift # Fn can be `_fn`

	case $fn in
		B) Reply=$1
			return ;;

		=) run "$2"
			eval "$1=\$Reply"
			return ;;

		\&) run "$1"
			to_bool "$Reply" && run "$2"
			return ;;

		\|) run "$1"
			to_bool "$Reply" || run "$2"
			return ;;

		W) while run "$1"; to_bool "$Reply"
			do run "$2"
			done
			Reply=N
			return ;;

		I) run "$1"
			if to_bool "$Reply"
			then run "$2"
			else run "$3"
			fi
			return ;;
	esac

	# Execute all the arguments
	set -- "$fn" "$@"
	while [ $# -gt 1 ]; do
		run "$2"
		_tmp=$1$UNIQ_SEP$Reply
		shift 2
		set -- "$_tmp" "$@"
	done
	_old_IFS=$IFS; IFS=$UNIQ_SEP && set -o noglob
	set -- $1 && IFS=$_old_IFS && set +o noglob

	local fn=${1#f}; shift # Fn can be `_fn`

	# Execute functions
	case $fn in
		# Arity 0
		R) TODO "$fn" ;;
		P) TODO "$fn" ;;

		# Arity 1
		C) run "$1"; run "$Reply" ;;
		Q) to_int "$1"; exit $Reply ;;
		D) run "$1"; set -- "$Reply"; dump "$1"; Reply="$1" ;;
		O) if to_str "$1"; [ "${Reply%\\}" = "$Reply" ]; then
				printf '%s\n' "$Reply"
			else
				printf '%s' "${Reply%?}"
			fi
			Reply=N ;;
		L) TODO "$fn" ;;
		!) ! to_bool "$1"; newbool ;;
		\~) to_int "$1"; Reply=i$(( - Reply )) ;;
		A) run "$1"; case $Reply in
			s*) Reply=i$(printf %d \'"$Reply") ;;
			i*) TODO ;; #printf '%b\n' '\060' octal ew
			esac ;;
		,) run "$1" ; new_ary "$Reply" ;;
		\[) run "$1"
			case $Reply in
				s*) Reply=s$(printf %c "$Reply") ;;
				[aA]*) TODO "$fn for arrays" ;;
			esac ;;
		\]) run "$1"
			case $Reply in
				s*) Reply=s${Reply#s?} ;;
				[aA]*) TODO "$fn for arrays" ;;
			esac ;;
		E) to_str "$1"; eval_kn "$Reply" ;;
		\$) to_str "$1"; Reply=s$( $Reply ) ;;

		# Arity 2
		\;) run "$1"; run "$2" ;;
		+) run "$1"; set -- "$Reply" "$2"; case $1 in
			i*) to_int "$2"; Reply=i$((${1#?} + Reply)) ;;
			s*) to_str "$2"; Reply=s${1#?}$Reply ;;
			[aA]*) TODO "$fn for arrays" ;;
			*)  die "unknown argument to $fn: $1" ;;
			esac ;;
		-) run "$1"; set -- "$Reply" "$2"; to_int "$2"; Reply=i$((${1#?} - Reply)) ;;
		\*) run "$1"; set -- "$eply" "$2"; case $1 in
			i*) to_int "$2"; Reply=i$((${1#?} + Reply)) ;;
			s*) TODO "$fn for strings" ;;
			[aA]*) TODO "$fn for arrays" ;;
			*)  die "unknown argument to $fn: $1"
			esac ;;
		/) run "$1"; set -- "$Reply" "$2"; to_int "$2"; Reply=i$((${1#?} / Reply)) ;;
		%) run "$1"; set -- "$Reply" "$2"; to_int "$2"; Reply=i$((${1#?} % Reply)) ;;
		^) run "$1"; set -- "$Reply" "$2"; case "$1" in
			i*) to_int "$2"; Reply=i$(echo "${1#?} ^ $Reply" | bc) ;; # no exponents in posix
			[aA]*) TODO "$fn for arrays" ;;
			*)  die "unknown argument to $fn: $1"
			esac ;;
		\?) run "$1"; set --  "$Reply" "$2"; run "$2"; are_equal "$1" "$Reply"; newbool ;;
		\<) run "$1"; compare "$Reply" "$2"; [ $Reply -lt 0 ]; newbool ;;
		\>) run "$1"; compare "$Reply" "$2"; [ $Reply -gt 0 ]; newbool ;;

		G) TODO "$fn" ;;
		S) TODO "$fn" ;;

		*) die 'unknown function: %s' "$1" ;;
	esac
}
