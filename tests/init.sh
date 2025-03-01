# source this file; set up for tests

# Copyright (C) 2009, 2010 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Using this file in a test
# =========================
#
# The typical skeleton of a test looks like this:
#
#   #!/bin/sh
#   . "${srcdir=.}/init.sh"; path_prepend_ .
#   Execute some commands.
#   Note that these commands are executed in a subdirectory, therefore you
#   need to prepend "../" to relative filenames in the build directory.
#   Note that the "path_prepend_ ." is useful only if the body of your
#   test invokes programs residing in the initial directory.
#   For example, if the programs you want to test are in src/, and this test
#   script is named tests/test-1, then you would use "path_prepend_ ../src",
#   or perhaps export PATH='$(abs_top_builddir)/src$(PATH_SEPARATOR)'"$$PATH"
#   to all tests via automake's TESTS_ENVIRONMENT.
#   Set the exit code 0 for success, 77 for skipped, or 1 or other for failure.
#   Use the skip_ and fail_ functions to print a diagnostic and then exit
#   with the corresponding exit code.
#   Exit $?

# Executing a test that uses this file
# ====================================
#
# Running a single test:
#   $ make check TESTS=test-foo.sh
#
# Running a single test, with verbose output:
#   $ make check TESTS=test-foo.sh VERBOSE=yes
#
# Running a single test, with single-stepping:
#   1. Go into a sub-shell:
#   $ bash
#   2. Set relevant environment variables from TESTS_ENVIRONMENT in the
#      Makefile:
#   $ export srcdir=../../tests # this is an example
#   3. Execute the commands from the test, copy&pasting them one by one:
#   $ . "$srcdir/init.sh"; path_prepend_ .
#   ...
#   4. Finally
#   $ exit

ME_=`expr "./$0" : '.*/\(.*\)$'`

# We use a trap below for cleanup.  This requires us to go through
# hoops to get the right exit status transported through the handler.
# So use `Exit STATUS' instead of `exit STATUS' inside of the tests.
# Turn off errexit here so that we don't trip the bug with OSF1/Tru64
# sh inside this function.
Exit () { set +e; (exit $1); exit $1; }

# Print warnings (e.g., about skipped and failed tests) to this file number.
# Override by defining to say, 9, in init.cfg, and putting say,
# "export ...ENVVAR_SETTINGS...; exec 9>&2; $(SHELL)" in the definition
# of TESTS_ENVIRONMENT in your tests/Makefile.am file.
# This is useful when using automake's parallel tests mode, to print
# the reason for skip/failure to console, rather than to the .log files.
: ${stderr_fileno_=2}

warn_() { echo "$@" 1>&$stderr_fileno_; }
fail_() { warn_ "$ME_: failed test: $@"; Exit 1; }
skip_() { warn_ "$ME_: skipped test: $@"; Exit 77; }
framework_failure_() { warn_ "$ME_: set-up failure: $@"; Exit 99; }

# Sanitize this shell to POSIX mode, if possible.
DUALCASE=1; export DUALCASE
if test -n "${ZSH_VERSION+set}" && (emulate sh) >/dev/null 2>&1; then
  emulate sh
  NULLCMD=:
  alias -g '${1+"$@"}'='"$@"'
  setopt NO_GLOB_SUBST
else
  case `(set -o) 2>/dev/null` in
    *posix*) set -o posix ;;
  esac
fi

# We require $(...) support unconditionally.
# We require a few additional shell features only when $EXEEXT is nonempty,
# in order to support automatic $EXEEXT emulation:
# - hyphen-containing alias names
# - we prefer to use ${var#...} substitution, rather than having
#   to work around lack of support for that feature.
# The following code attempts to find a shell with support for these features.
# If the current shell passes the test, we're done.  Otherwise, test other
# shells until we find one that passes.  If one is found, re-exec it.
# If no acceptable shell is found, skip the current test.
#
# The "...set -x; P=1 true 2>err..." test is to disqualify any shell that
# emits "P=1" into err, as /bin/sh from SunOS 5.11 and OpenBSD 4.7 do.
#
# Use "9" to indicate success (rather than 0), in case some shell acts
# like Solaris 10's /bin/sh but exits successfully instead of with status 2.

# Eval this code in a subshell to determine a shell's suitability.
# 10 - passes all tests; ok to use
#  9 - ok, but enabling "set -x" corrupts application stderr; prefer higher score
#  ? - not ok
gl_shell_test_script_='
test $(echo y) = y || exit 1
score_=10
if test "$VERBOSE" = yes; then
  test -n "$( (exec 3>&1; set -x; P=1 true 2>&3) 2> /dev/null)" && score_=9
fi
test -z "$EXEEXT" && exit $score_
shopt -s expand_aliases
alias a-b="echo zoo"
v=abx
     test ${v%x} = ab \
  && test ${v#a} = bx \
  && test $(a-b) = zoo \
  && exit $score_
'

if test "x$1" = "x--no-reexec"; then
  shift
else
  # Assume a working shell.  Export to subshells (setup_ needs this).
  gl_set_x_corrupts_stderr_=false
  export gl_set_x_corrupts_stderr_

  # Record the first marginally acceptable shell.
  marginal_=

  # Search for a shell that meets our requirements.
  for re_shell_ in __current__ "${CONFIG_SHELL:-no_shell}" \
      /bin/sh bash dash zsh pdksh fail
  do
    test "$re_shell_" = no_shell && continue

    # If we've made it all the way to the sentinel, "fail" without
    # finding even a marginal shell, skip this test.
    if test "$re_shell_" = fail; then
      test -z "$marginal_" && skip_ failed to find an adequate shell
      re_shell_=$marginal_
      break
    fi

    # When testing the current shell, simply "eval" the test code.
    # Otherwise, run it via $re_shell_ -c ...
    if test "$re_shell_" = __current__; then
      # 'eval'ing this code makes Solaris 10's /bin/sh exit with
      # $? set to 2.  It does not evaluate any of the code after the
      # "unexpected" first `('.  Thus, we must run it in a subshell.
      ( eval "$gl_shell_test_script_" ) > /dev/null 2>&1
    else
      "$re_shell_" -c "$gl_shell_test_script_" 2>/dev/null
    fi

    st_=$?

    # $re_shell_ works just fine.  Use it.
    test $st_ = 10 && break

    # If this is our first marginally acceptable shell, remember it.
    if test "$st_:$marginal_" = 9: ; then
      marginal_="$re_shell_"
      gl_set_x_corrupts_stderr_=true
    fi
  done

  if test "$re_shell_" != __current__; then
    # Found a usable shell.  Preserve -v and -x.
    case $- in
      *v*x* | *x*v*) opts_=-vx ;;
      *v*) opts_=-v ;;
      *x*) opts_=-x ;;
      *) opts_= ;;
    esac
    exec "$re_shell_" $opts_ "$0" --no-reexec "$@"
    echo "$ME_: exec failed" 1>&2
    exit 127
  fi
fi

test -n "$EXEEXT" && shopt -s expand_aliases

# Enable glibc's malloc-perturbing option.
# This is cheap and useful for exposing code that depends on the fact that
# malloc-related functions often return memory that is mostly zeroed.
# If you have the time and cycles, use valgrind to do an even better job.
: ${MALLOC_PERTURB_=87}
export MALLOC_PERTURB_

# This is a stub function that is run upon trap (upon regular exit and
# interrupt).  Override it with a per-test function, e.g., to unmount
# a partition, or to undo any other global state changes.
cleanup_() { :; }

if ( diff --version < /dev/null 2>&1 | grep GNU ) > /dev/null 2>&1; then
  compare() { diff -u "$@"; }
elif ( cmp --version < /dev/null 2>&1 | grep GNU ) > /dev/null 2>&1; then
  compare() { cmp -s "$@"; }
else
  compare() { cmp "$@"; }
fi

# An arbitrary prefix to help distinguish test directories.
testdir_prefix_() { printf gt; }

# Run the user-overridable cleanup_ function, remove the temporary
# directory and exit with the incoming value of $?.
remove_tmp_()
{
  __st=$?
  cleanup_
  # cd out of the directory we're about to remove
  cd "$initial_cwd_" || cd / || cd /tmp
  chmod -R u+rwx "$test_dir_"
  # If removal fails and exit status was to be 0, then change it to 1.
  rm -rf "$test_dir_" || { test $__st = 0 && __st=1; }
  exit $__st
}

# Given a directory name, DIR, if every entry in it that matches *.exe
# contains only the specified bytes (see the case stmt below), then print
# a space-separated list of those names and return 0.  Otherwise, don't
# print anything and return 1.  Naming constraints apply also to DIR.
find_exe_basenames_()
{
  feb_dir_=$1
  feb_fail_=0
  feb_result_=
  feb_sp_=
  for feb_file_ in $feb_dir_/*.exe; do
    # If there was no *.exe file, or there existed a file named "*.exe" that
    # was deleted between the above glob expansion and the existence test
    # below, just skip it.
    test "x$feb_file_" = "x$feb_dir_/*.exe" && test ! -f "$feb_file_" \
      && continue
    case $feb_file_ in
      *[!-a-zA-Z/0-9_.+]*) feb_fail_=1; break;;
      *) # Remove leading file name components as well as the .exe suffix.
         feb_file_=${feb_file_##*/}
         feb_file_=${feb_file_%.exe}
         feb_result_="$feb_result_$feb_sp_$feb_file_";;
    esac
    feb_sp_=' '
  done
  test $feb_fail_ = 0 && printf %s "$feb_result_"
  return $feb_fail_
}

# Consider the files in directory, $1.
# For each file name of the form PROG.exe, create an alias named
# PROG that simply invokes PROG.exe, then return 0.  If any selected
# file name or the directory name, $1, contains an unexpected character,
# define no alias and return 1.
create_exe_shims_()
{
  case $EXEEXT in
    '') return 0 ;;
    .exe) ;;
    *) echo "$0: unexpected \$EXEEXT value: $EXEEXT" 1>&2; return 1 ;;
  esac

  base_names_=`find_exe_basenames_ $1` \
    || { echo "$0 (exe_shim): skipping directory: $1" 1>&2; return 1; }

  if test -n "$base_names_"; then
    for base_ in $base_names_; do
      alias "$base_"="$base_$EXEEXT"
    done
  fi

  return 0
}

# Use this function to prepend to PATH an absolute name for each
# specified, possibly-$initial_cwd_-relative, directory.
path_prepend_()
{
  while test $# != 0; do
    path_dir_=$1
    case $path_dir_ in
      '') fail_ "invalid path dir: '$1'";;
      /*) abs_path_dir_=$path_dir_;;
      *) abs_path_dir_=`cd "$initial_cwd_/$path_dir_" && echo "$PWD"` \
           || fail_ "invalid path dir: $path_dir_";;
    esac
    case $abs_path_dir_ in
      *:*) fail_ "invalid path dir: '$abs_path_dir_'";;
    esac
    PATH="$abs_path_dir_:$PATH"

    # Create an alias, FOO, for each FOO.exe in this directory.
    create_exe_shims_ "$abs_path_dir_" \
      || fail_ "something failed (above): $abs_path_dir_"
    shift
  done
  export PATH
}

setup_()
{
  if test "$VERBOSE" = yes; then
    # Test whether set -x may cause the selected shell to corrupt an
    # application's stderr.  Many do, including zsh-4.3.10 and the /bin/sh
    # from SunOS 5.11, OpenBSD 4.7 and Irix 5.x and 6.5.
    # If enabling verbose output this way would cause trouble, simply
    # issue a warning and refrain.
    if $gl_set_x_corrupts_stderr_; then
      warn_ "using SHELL=$SHELL with 'set -x' corrupts stderr"
    else
      set -x
    fi
  fi

  initial_cwd_=$PWD

  pfx_=`testdir_prefix_`
  test_dir_=`mktempd_ "$initial_cwd_" "$pfx_-$ME_.XXXX"` \
    || fail_ "failed to create temporary directory in $initial_cwd_"
  cd "$test_dir_"

  # This trap statement, along with a trap on 0 below, ensure that the
  # temporary directory, $test_dir_, is removed upon exit as well as
  # upon receipt of any of the listed signals.
  for sig_ in 1 2 3 13 15; do
    eval "trap 'Exit $(expr $sig_ + 128)' $sig_"
  done
}

# Create a temporary directory, much like mktemp -d does.
# Written by Jim Meyering.
#
# Usage: mktempd_ /tmp phoey.XXXXXXXXXX
#
# First, try to use the mktemp program.
# Failing that, we'll roll our own mktemp-like function:
#  - try to get random bytes from /dev/urandom
#  - failing that, generate output from a combination of quickly-varying
#      sources and gzip.  Ignore non-varying gzip header, and extract
#      "random" bits from there.
#  - given those bits, map to file-name bytes using tr, and try to create
#      the desired directory.
#  - make only $MAX_TRIES_ attempts

# Helper function.  Print $N pseudo-random bytes from a-zA-Z0-9.
rand_bytes_()
{
  n_=$1

  # Maybe try openssl rand -base64 $n_prime_|tr '+/=\012' abcd first?
  # But if they have openssl, they probably have mktemp, too.

  chars_=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789
  dev_rand_=/dev/urandom
  if test -r "$dev_rand_"; then
    # Note: 256-length($chars_) == 194; 3 copies of $chars_ is 186 + 8 = 194.
    dd ibs=$n_ count=1 if=$dev_rand_ 2>/dev/null \
      | LC_ALL=C tr -c $chars_ 01234567$chars_$chars_$chars_
    return
  fi

  n_plus_50_=`expr $n_ + 50`
  cmds_='date; date +%N; free; who -a; w; ps auxww; ps ef; netstat -n'
  data_=` (eval "$cmds_") 2>&1 | gzip `

  # Ensure that $data_ has length at least 50+$n_
  while :; do
    len_=`echo "$data_"|wc -c`
    test $n_plus_50_ -le $len_ && break;
    data_=` (echo "$data_"; eval "$cmds_") 2>&1 | gzip `
  done

  echo "$data_" \
    | dd bs=1 skip=50 count=$n_ 2>/dev/null \
    | LC_ALL=C tr -c $chars_ 01234567$chars_$chars_$chars_
}

mktempd_()
{
  case $# in
  2);;
  *) fail_ "Usage: $ME DIR TEMPLATE";;
  esac

  destdir_=$(readlink -f $1)
  template_=$2

  MAX_TRIES_=4

  # Disallow any trailing slash on specified destdir:
  # it would subvert the post-mktemp "case"-based destdir test.
  case $destdir_ in
  /) ;;
  */) fail_ "invalid destination dir: remove trailing slash(es)";;
  esac

  case $template_ in
  *XXXX) ;;
  *) fail_ "invalid template: $template_ (must have a suffix of at least 4 X's)";;
  esac

  fail=0

  # First, try to use mktemp.
  d=$(readlink -f $(TMPDIR="$destdir_" mktemp -d "$template_" 2>/dev/null)) \
    || fail=1

  # The resulting name must be in the specified directory.
  case $d in "$destdir_"*);; *) fail=1;; esac

  # It must have created the directory.
  test -d "$d" || fail=1

  # It must have 0700 permissions.  Handle sticky "S" bits.
  perms=`ls -dgo "$d" 2>/dev/null|tr S -` || fail=1
  case $perms in drwx------*) ;; *) fail=1;; esac

  test $fail = 0 && {
    echo "$d"
    return
  }

  # If we reach this point, we'll have to create a directory manually.

  # Get a copy of the template without its suffix of X's.
  base_template_=`echo "$template_"|sed 's/XX*$//'`

  # Calculate how many X's we've just removed.
  template_length_=`echo "$template_" | wc -c`
  nx_=`echo "$base_template_" | wc -c`
  nx_=`expr $template_length_ - $nx_`

  err_=
  i_=1
  while :; do
    X_=`rand_bytes_ $nx_`
    candidate_dir_="$destdir_/$base_template_$X_"
    err_=`mkdir -m 0700 "$candidate_dir_" 2>&1` \
      && { echo "$candidate_dir_"; return; }
    test $MAX_TRIES_ -le $i_ && break;
    i_=`expr $i_ + 1`
  done
  fail_ "$err_"
}

# If you want to override the testdir_prefix_ function,
# or to add more utility functions, use this file.
test -f "$srcdir/init.cfg" \
  && . "$srcdir/init.cfg"

setup_ "$@"
# This trap is here, rather than in the setup_ function, because some
# shells run the exit trap at shell function exit, rather than script exit.
trap remove_tmp_ 0
