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
	IFS=$FN_SEP; set -o noglob
	set -- $1; unset IFS; set +o noglob


	# Execute arguments for functions that need them executed
	case ${1#f} in [!B=\&\|WI]) # TODO: is it `!` or `^`?
		# Execute all the arguments
		while [ $# -gt 1 ]; do
			run "$2"
			tmp=$1$UNIQ_SEP$Reply
			shift 2
			set -- "$tmp" "$@"
		done
		IFS=$UNIQ_SEP; set -o noglob
		set -- $1; unset IFS; set +o noglob
	esac

	fn=${1#f}
	shift

	# Execute functions
	case $fn in
	# Extensions
		E) # EVAL
			to_str "$1"
			eval_kn "$Reply" ;;

		\$) # $ (system)
			to_str "$1"
			Reply=s$( $Reply ) ;;

		V) # VALUE
			to_str "$1"
			eval "run \$v${1#s}" ;;


	# Arity 0
		P) # PROMPT
			read -r Reply || { Reply=N; return; }
			# This could be optimized
			r=$(printf \\r)
			while tmp=${Reply%"$r"}; [ ${#tmp} -ne ${#Reply} ]; do
				Reply=${Reply%?}
			done
			Reply=s$Reply ;;

		R) # RANDOM
			Reply=i$(awk 'BEGIN{ srand(); print int(rand() * 65535); exit }') ;;


	# Arity 1
		B) # BLOCK {args weren't evaluated}
			Reply=$1 ;;

		C) # CALL
			run "$1" ;;

		Q) # QUIT
			to_int "$1"
			exit $Reply ;;

		D) # DUMP
			dump "$1"
			Reply="$1" ;;

		O) # OUTPUT
			to_str "$1"
			if [ "${Reply%\\}" = "$Reply" ]; then
				printf '%s\n' "$Reply"
			else
				printf '%s' "${Reply%?}"
			fi
			Reply=N ;;

		L) # LENGTH
			case $1 in
			s*) Reply=i$(( ${#1} - 1 )) ;; # Have to subtract 1 for prefix
			a*) Reply=${1%%"$ARY_SEP"*}; Reply=i${Reply#?} ;;
			*)
				to_ary "$1"
				Reply=${Reply%%"$ARY_SEP"*}
				Reply=i${Reply#?} ;;
			# *)  die "unknown argument to $fn: $1" ;;
			esac ;;

		!) # ! (not)
			! to_bool "$1"
			newbool ;;

		\~) # ~ (negate)
			to_int "$1"
			Reply=i$(( - Reply )) ;;

		A) # ASCII
			case $1 in
			s*) Reply=i$(printf %d \'"$1") ;;
			i*) TODO ;; #printf '%b\n' '\060' octal ew
			*)  die "unknown argument to $fn: $1" ;;
			esac ;;

		,) # , (box)
			new_ary "$1" ;;

		\[) # [ (head)
			case $1 in
				s*) Reply=$(printf %.2s "$1") ;;
				a*) IFS=$ARY_SEP && set -o noglob
					set -- $1 && set +o noglob && unset IFS
					expandref "$2" ;;
				*)  die "unknown argument to $fn: $1"
			esac ;;

		\]) # ] (tail)
			case $1 in
				s*) Reply=s${1#s?} ;;
				a*) IFS=$ARY_SEP && set -o noglob
					set -- $1 && set +o noglob && unset IFS
					shift 2; new_ary "$@" ;;
				*)  die "unknown argument to $fn: $1"
			esac ;;


	# Arity 2
		+) # + (add)
			case $1 in
			i*) to_int "$2"; Reply=i$((${1#?} + Reply)) ;;
			s*) to_str "$2"; Reply=s${1#?}$Reply ;;
			a0) to_ary "$2";; # TODO: make this not a separate case if we decide on `a0:`
			a*) to_ary "$2"
				IFS=$ARY_SEP; set -o noglob
				set -- ${1#*"$ARY_SEP"} ${Reply#*"$ARY_SEP"}
				unset IFS; set +o noglob
				new_ary "$@" ;;
			*)  die "unknown argument to $fn: $1" ;;
			esac ;;

		-) # - (subtract)
			to_int "$2"
			Reply=i$((${1#?} - Reply)) ;;

		\*) # * (multiply)
			to_int "$2" # all three cases happen to use ints for the second num.
			case $1 in
			i*) Reply=i$((${1#?} * Reply)) ;;
			s*) tmp=$Reply; Reply=s
				while [ $((tmp -= 1)) -ge 0 ]; do
					Reply=$Reply${1#s}
				done ;;
			a0) Reply=a0 ;;
			a*) tmp=
				while [ $((Reply -= 1)) -ge 0 ]; do
					tmp=$tmp${tmp:+$ARY_SEP}${1#*"$ARY_SEP"}
				done
				IFS=$ARY_SEP; set -o noglob
				set -- $tmp
				unset IFS; set +o noglob
				new_ary "$@" ;;
			*)  die "unknown argument to $fn: $1"
			esac ;;

		/) # / (divide)
			to_int "$2"
			Reply=i$((${1#?} / Reply)) ;;

		%) # % (modulo)
			to_int "$2"
			Reply=i$((${1#?} % Reply)) ;;

		^) # ^ (power)
			case $1 in
			i*) to_int "$2"; Reply=i$(echo "${1#?} ^ $Reply" | bc) ;; # no exponents in posix
			a*) to_str "$2"; ary_join "$Reply" "$1"; Reply=s$Reply ;;
			*)  die "unknown argument to $fn: $1"
			esac ;;

		\<) # < (less-than)
			compare "$@"
			[ $Reply -lt 0 ]
			newbool ;;

		\>) compare "$@"
			[ $Reply -gt 0 ]
			newbool ;;

		\?) # ? (equals)
			are_equal "$@"
			newbool ;;

		\&) # & (and) {args weren't evaluated}
			run "$1"
			to_bool "$Reply" && run "$2" ;;

		\|) # | (or) {args weren't evaluated}
			run "$1"
			to_bool "$Reply" || run "$2" ;;

		\;) # ; (then)
			Reply=$2 ;; # We've already actually executed it

		=) # = (assign) {args weren't evaluated}
			run "$2"
			eval "$1=\$Reply" ;;

		W) # WHILE {args weren't evaluated}
			while run "$1"; to_bool "$Reply"
			do run "$2"
			done
			Reply=N ;;


	# Arity 3
		I) # IF {args weren't evaluated}
			run "$1"
			if to_bool "$Reply"
			then run "$2"
			else run "$3"
			fi ;;

		G) # GET
			local start len
			to_int "$2"; start=$Reply
			to_int "$3"; len=$Reply
			case $1 in
			s*) [ "$len" = 0 ] && { Reply=s; return; }
				TODO "!"
				;;
			a*)
				[ "$len" = 0 ] && { Reply=a0; return; }

				IFS=$ARY_SEP; set -o noglob
				set -- $1; unset IFS; set +o noglob
				shift $((start + 1)) # `+1` to get rid of the length

				Reply=a$len
				while [ $((len -= 1)) -ge 0 ]; do
					Reply=$Reply$ARY_SEP$1
					shift
				done
				;;
			*)  die "unknown argument to $fn: $1"
			esac ;;

	# Arity 4
		S) # SET
			case $1 in
			s*) ;;
			a*) ;;
			*)  die "unknown argument to $fn: $1"
			esac 
			TODO "!"
			;;

		*) die 'unknown function: %s' "$1" ;;
	esac
}
