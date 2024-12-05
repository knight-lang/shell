## Runs a Knight value.
run () {
	# Handle non-functions specially.
	case $1 in
	# Variables. To access their values we need to `eval` them. (Note that
	# the `set -o nounset` we did will cause undefined variables to abort,
	# albeit with a not-so-clear error message :-P).
	v*) eval "Reply=\$$1"; return ;;

	# Function reference. Replace the current arguments with the expanded
	# value. Note this function variant doesn't `return`, unlike the others.
	F?*) IFS=; eval "set -- \$$1"; unset IFS ;;

	# All other non-functions are just returned as-is
	[!f]*) Reply=$1; return
	esac

	# Explode the arguments
	IFS=$FN_SEP; set -- $1; unset IFS

	# Execute arguments for functions which always execute their arguments.
	case ${1#f} in [!B=\&\|WI])
		# Execute all the arguments
		while [ $# -gt 1 ]; do
			run "$2"
			tmp=$1$EXEC_SEP$Reply
			shift 2
			set -- "$tmp" "$@"
		done
		IFS=$EXEC_SEP; set -- $1; unset IFS
	esac

	## Set the function name. Mainly used for error messages, and it just so
	# happens that it's never clobbered (as it's always used before calling
	# a function that'll eventually call `run`.)
	fn=${1#f}
	shift

	## Execute all the arguments
	case $fn in
    ########################################################################
    #                                                                      #
    #                              Extensions                              #
    #                                                                      #
    ########################################################################
	E) # EVAL
		to_str "$1"
		next_expr <<-EOS
			$Reply
		EOS
		run "$Reply" ;;

	\$) # $ (system)
		to_str "$1"
		Reply=s$( $Reply ) ;;

	V) # VALUE
		to_str "$1"
		eval "run \$v${1#s}" ;;

    ########################################################################
    #                                                                      #
    #                               Arity 0                                #
    #                                                                      #
    ########################################################################
	P) # PROMPT
		# Read a single line in. If `read` returns an error, it means we
		# are at the end of the file. However, it'll still populate the
		# `$Reply` if there was no trailing newline, so we need to make
		# sure `$Reply` is empty before returning `NULL`.
		if ! read -r Reply && [ -z "$Reply" ]; then
			Reply=N
			return
		fi

		# Delete trailing `\r`s.
		while [ "${Reply%$CARRIAGE_RETURN}" != "$Reply" ]; do
			Reply=${Reply%?}
		done

		Reply=s$Reply ;;

	R) # RANDOM
		# Posix shells don't have random themselves, so we have
		# to dip into AWK.
		Reply=i$(awk "BEGIN {
			${seed+srand($seed)} # Seed the random number
			print int(rand() * 4294967295) # AWK uses floats
			exit
		}")
		seed=${Reply#i} ;; # Reset the seed so the next awk works.

    ########################################################################
    #                                                                      #
    #                               Arity 1                                #
    #                                                                      #
    ########################################################################
	B) # BLOCK {args weren't evaluated}
		Reply=$1 ;;

	C) # CALL
		run "$1" ;;

	Q) # QUIT
		to_int "$1"
		exit $Reply ;;

	D) # DUMP
		dump "$1"
		Reply=$1 ;;

	O) # OUTPUT
		to_str "$1"
		case $Reply in
		*\\) printf '%s'   "${Reply%?}" ;;
		*)   printf '%s\n' "$Reply"     ;;
		esac
		Reply=N ;;

	L) # LENGTH
		case $1 in
		s*) Reply=i$(( ${#1} - 1 )) ;; # -1 b/c of prefix
		a*) Reply=${1%%$ARY_SEP*} Reply=i${Reply#?} ;;
 		# Support Knight 2.0.1 behaviour
		*)  to_ary "$1"; tmp=${Reply%%$ARY_SEP*} Reply=i${tmp#?}
		esac ;;

	!) # ! (not)
		! to_bool "$1"
		newbool ;;

	\~) # ~ (negate)
		to_int "$1"
		Reply=i$(( -Reply )) ;;

	A) # ASCII
		case $1 in
		# Rely on little-known-fact that `printf %d 'str` prints the
		# codepoint of `str`'s first character.
		s*) Reply=i$(printf %d \'"${1#s}") ;;

		# Use a nested `printf`; `printf %b` interprets `\` escapes, and
		# the inner one returns an octal variation. (`x` allows for
		# trailing newlines)
		i*) tmp=s$(printf %bx \\$(printf %o ${1#?})) Reply=${tmp%x};;
		*)  die "unknown argument to $fn: %s" "$1"
		esac ;;

	,) # , (box)
		new_ary "$1" ;;

	\[) # [ (head)
		case $1 in
		s*) Reply=$(printf %.2s "$1") ;; # ".2s" will also print `s`.
		a*) IFS=$ARY_SEP; set -- $1; unset IFS; expandref "$2" ;;
		*)  die "unknown argument to $fn: %s" "$1"
		esac ;;

	\]) # ] (tail)
		case $1 in
		s*) Reply=s${1#s?} ;;
		a*) IFS=$ARY_SEP; set -- $1; unset IFS; shift 2; new_ary "$@" ;;
		*)  die "unknown argument to $fn: %s" "$1"
		esac ;;

    ########################################################################
    #                                                                      #
    #                               Arity 2                                #
    #                                                                      #
    ########################################################################
	+) # + (add)
		case $1 in
		i*) to_int "$2"; Reply=i$((${1#?} + Reply)) ;;
		s*) to_str "$2"; Reply=s${1#?}$Reply ;;
		a0) to_ary "$2" ;;
		a*) # If there was a way to count `$ARY_SEP` this'd be easier
			to_ary "$2"
			IFS=$ARY_SEP
			set -- ${1#*$ARY_SEP} ${Reply#*$ARY_SEP}
			unset IFS
			new_ary "$@" ;;
		*) die "unknown argument to $fn: %s" "$1"
		esac ;;

	-) # - (subtract)
		to_int "$2"
		Reply=i$((${1#?} - Reply)) ;;

	\*) # * (multiply)
		to_int "$2" # all 3 cases happen to use ints lol.

		case $1 in
		i*) Reply=i$((${1#?} * Reply)) ;;
		s*) tmp=$Reply Reply=s
			while [ $((tmp -= 1)) -ge 0 ]; do
				Reply=$Reply${1#s}
			done ;;
		a0) Reply=a0 ;;
		a*)
			amount=$Reply
			Reply=${1#?}
			Reply=a$((${Reply%%$ARY_SEP*} * amount))
			while [ $((amount -= 1)) -ge 0 ]; do
				Reply=$Reply$ARY_SEP${1#*$ARY_SEP}
			done ;;
		*)  die "unknown argument to $fn: %s" "$1"
		esac ;;

	/) # / (divide)
		to_int "$2"
		Reply=i$((${1#?} / $Reply)) ;;

	%) # % (modulo)
		to_int "$2"
		Reply=i$((${1#?} % Reply)) ;;

	^) # ^ (power)
		case $1 in
		# (No exponents in sh, so we gotta use `bc`.)
		i*) to_int "$2"; Reply=i$(echo ${1#i} \^ $Reply | bc) ;;
		a*) to_str "$2"; ary_join "$Reply" "$1"; Reply=s$Reply ;;
		*)  die "unknown argument to $fn: %s" "$1"
		esac ;;

	\<) # < (less-than)
		compare "$@"
		[ $Reply -lt 0 ]
		newbool ;;

	\>) # > (greater-than)
		compare "$@"
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
		Reply=$2 ;; # All arguments are already executed.

	=) # = (assign) {args weren't evaluated}
		# Make sure we're only given variables
		case $1 in [!v]*)
			die "can only assign to variables (was given %s)" "$1"
		esac
		run "$2"
		eval "$1=\$Reply" ;;

	W) # WHILE {args weren't evaluated}
		while run "$1"; to_bool "$Reply"; do
			run "$2"
		done
		Reply=N ;;

    ########################################################################
    #                                                                      #
    #                               Arity 3                                #
    #                                                                      #
    ########################################################################

	I) # IF {args weren't evaluated}
		run "$1"
		to_bool "$Reply"
		shift $((1 + $?))
		run "$1" ;;

	G) # GET
		# Both arg 2 and arg 3 are always ints.
		to_int "$2"; set -- "$1" $Reply "$3"
		to_int "$3" # Don't need to `set` as we use `$Reply` directly.

		case $1 in
		s*) # Use AWK. (Could do manually but that's a pain)
			Reply=$(awk 'BEGIN{
				print substr(ARGV[1], ARGV[2]+1, ARGV[3]) "x"
			}' "${1#s}" $2 $Reply)
			Reply=s${Reply%x} ;;
		a*)
			if [ $Reply = 0 ] || [ "$1" = a0 ]; then
				Reply=a0
				return
			fi

			IFS=$ARY_SEP; set -- "$Reply" "$2" $1; unset IFS
			len=$1
			shift $(($2 + 3)) # `+3` for len, start, and "a#"

			Reply=a$len
			while [ $((len -= 1)) -ge 0 ]; do
				Reply=$Reply$ARY_SEP$1
				shift
			done ;;
		*)  die "unknown argument to $fn: %s" "$1"
		esac ;;

    ########################################################################
    #                                                                      #
    #                               Arity 4                                #
    #                                                                      #
    ########################################################################
	S) # SET
		to_int "$2"; set -- "$1" $Reply "$3" "$4"
		to_int "$3"; set -- "$1" $2 $Reply "$4"
		case $1 in
		s*) # Again, no substr, gotta use awk.
			to_str "$4"
			Reply=s$(awk 'BEGIN{
			print substr(ARGV[1], 1, ARGV[2]) \
				ARGV[4] \
				substr(ARGV[1], ARGV[2] + ARGV[3]+1) \
				"x"
			}' "${1#s}" $2 $3 "$Reply")
			Reply=${Reply%x} ;;
		a*)
			to_ary "$4"

			len=${Reply%%$ARY_SEP*} len=${len#a}
			Reply=$Reply$ARY_SEP repl=${Reply#*$ARY_SEP}
			tmp=${1%%$ARY_SEP*} tmp=${tmp#a}
			Reply=a$((len + tmp))$ARY_SEP

			ary=$1$ARY_SEP ary=${ary#*$ARY_SEP}
			start=$2 len=$3

			# Get the starting portion
			while [ $((start -= 1)) -ge 0 ]; do
				tmp=${ary#*$ARY_SEP}
				Reply=$Reply${ary%"$tmp"}
				ary=$tmp
			done

			# Add replacement
			Reply=$Reply$repl

			# Delete unwanted elements
			while [ $((len -= 1)) -ge 0 ]; do
				ary=${ary#*$ARY_SEP}
			done

			Reply=$Reply$ary Reply=${Reply%$ARY_SEP} ;;
		*)  die "unknown argument to $fn: %s" "$1"
		esac ;;
	*) die 'unknown function: %s' "$1"
	esac
}
