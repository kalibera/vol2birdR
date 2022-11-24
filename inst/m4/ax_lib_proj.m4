#
# SYNOPSIS
#
#   AC_LIB_PROJ([keepvar])
#
#   Optional argument 'keepvar' that will indicate to the script that CPPFLAGS & LDFLAGS should be restored after
#   macro has been run.
#
# DESCRIPTION
#
#   Macro for identifying PROJ.4 (and/or) PROJ.6 library. 
#
#   The macro provides two options.
#
#   --with-proj=[yes | no | path] 
#                        where path can either be a proj-root or a commaseparated list of <root>/include,<other-root>/lib
#                        default is "yes" meaning that pkg-config first will be used to identify compiler flags. After that, if on mac and
#                        pkg-config couldn't be found, brew will be identified and used to specify generic include/library flags.
#        
#                        If path is specified, then this path will be used for an atempt to compile the code.
#
#
#   The code will first try to identify PROJ.6, then if unsuccessful PROJ.4. If it can't find PROJ >= 6, it will
#   revert to PROJ < 6.
#
#   The macro first checks if with-proj was specified with path or not. If path was specified, that include/library
#   paths will be used for setting CFLAGS & LIBS and try to compile the software. This branch of the macro will also
#   ensure that it can find projects.h/proj.h in the specified include-dir and libproj* in specified lib-dir. If that isn't possible
#   the macro will abort since there must be a manual error.
#
#   If path wasn't specified, the macro will instead use pkg-config to identify CFLAGS & LIBS if available. If that doesn't work if will keep
#   on by checking if homebrew is available and in that case use the standard prefix as include/lib.
#
#   As a final resort, the macro will go back to use standard paths.
#
#   The following variables will be set after this function has been run.
#
#   PROJ_FOUND=yes|no         - If proj could be identified or not.
#   PROJ_SUPPRESSED=yes|no    - If proj actively was suppressed by user (--with-proj=no)
#   PROJ_VARIANT=4|6          - If proj variant 4 or >= 6 was identified.
#   PROJ_CFLAGS=..            - Compiler flags that should be used.
#   PROJ_LIBS=..              - Libs that should be used.
#   PROJ_LDFLAGS=..           - Linker flags that should be used.
#
#   CPPFLAGS & LIBS will be updated with new flags unless AX_LIB_PROJ is called with [keepvar]. If not keepvar is specified
#   both CPPFLAGS & LIBS will be updated with flags used when successfully identifying the proj-version
#
# LICENSE
#   Copyright (c) 2022 Anders Henja (anders@henjab.se)
#
#   Copying and distribution of this file, with or without modification, are
#   permitted in any medium without royalty provided the copyright notice
#   and this notice are preserved. This file is offered as-is, without any
#   warranty.
AC_DEFUN([AX_LIB_PROJ], [

AC_REQUIRE([AC_PROG_SED])

PROJ_CFLAGS=""
PROJ_LDFLAGS=""
PROJ_LIBS=""
PROJ_VARIANT=X
PROJ_FOUND=no
PROJ_SUPPRESSED=no

ax_lib_proj_path=
ax_lib_proj_with_proj=yes
ax_lib_proj_useproj6=no
ax_lib_proj_proj4ok=yes
ax_lib_proj_proj6ok=no
ax_lib_proj_pkg_config_identified=no
ax_lib_proj_fun_arg=$1 # Store argument when calling AX_LIB_PROJ([keepvar])

# Add a default --with-proj configuration option.
AC_ARG_WITH([proj],
  AS_HELP_STRING(
    [--with-proj=[yes|no|<path to proj>]],
            [location of <proj>-root or a comma separated list specifying include and library directory]
  ),
  [ if test "$withval" = "no" -o "$withval" = "yes"; then
      ax_lib_proj_with_proj="$withval"
    else
      ax_lib_proj_with_proj="yes"
      ax_lib_proj_path="$withval"
    fi
  ],
  [ax_lib_proj_with_proj="yes"]
)


# Keep track of LIBS before we start identifying PROJ
ax_lib_proj_save_LDFLAGS=${LDFLAGS}
ax_lib_proj_save_LIBS=${LIBS}
ax_lib_proj_save_CPPFLAGS=${CPPFLAGS}

if [[ "$ax_lib_proj_with_proj" != "no" ]]; then
  if [[ "$ax_lib_proj_with_proj" = "yes" -a "$ax_lib_proj_path" = "" ]]; then
    AC_MSG_CHECKING([for pkg-config])
    pkg-config proj > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      AC_MSG_RESULT([yes])
      ax_lib_proj_pkg_config_identified=yes

      AC_MSG_CHECKING([for proj CFLAGS])
      PROJ_CFLAGS=`pkg-config --cflags proj`
      AC_MSG_RESULT($PROJ_CFLAGS)

	  AC_MSG_CHECKING([for proj LDFLAGS])
	  PROJ_LDFLAGS=`pkg-config --libs-only-L proj`
      AC_MSG_RESULT($PROJ_LDFLAGS)

	  AC_MSG_CHECKING([for proj LIBS])
	  PROJ_LIBS=`pkg-config --libs-only-l proj`
	  AC_MSG_CHECKING([$PROJ_LIBS])
    else
      AC_MSG_RESULT([no])
    fi
  fi

  if [[ "$ax_lib_proj_pkg_config_identified" = "no" -a "$ax_lib_proj_path" != "" ]]; then
    if [[ "`echo $ax_lib_proj_path | grep ','`" = "" ]]; then
      ax_lib_proj_inc=$ax_lib_proj_path/include
      ax_lib_proj_lib=$ax_lib_proj_path/lib
    else
      ax_lib_proj_inc="`echo $ax_lib_proj_path |cut -f1 -d,`"
      ax_lib_proj_lib="`echo $ax_lib_proj_path |cut -f2 -d,`"
    fi
  
    AC_MSG_CHECKING([Checking if proj.h or projects.h can be found in $ax_lib_proj_inc/])
    if [[ ! -f "$ax_lib_proj_inc/proj.h" -a ! -f "$ax_lib_proj_inc/projects.h" ]]; then
      AC_MSG_RESULT([no])
      AC_MSG_ERROR([Could not identify proj.h or projects.h in include directory $ax_lib_proj_inc, aborting!])
    else
      AC_MSG_RESULT([yes])
    fi
    AC_MSG_CHECKING([Checking if libproj can be found in proj-path])
    TMP=`ls -1 "$ax_lib_proj_lib"/libproj.* 2>/dev/null`
    if [[ "$TMP" = "" ]]; then
      AC_MSG_RESULT([no])
      AC_MSG_ERROR([Could not identify libproj in directory $ax_lib_proj_inc, aborting!])
    else
      AC_MSG_RESULT([yes])
    fi
    
    PROJ_LDFLAGS="-L$ax_lib_proj_lib"
    PROJ_LIBS="-lproj"
    PROJ_CFLAGS="-I$ax_lib_proj_inc"
  elif [[ "$ax_lib_proj_pkg_config_identified" = "no" ]]; then
    # If we can't identify pkg-config but is on mac, we might be able to use
    # homebrew to at least get basic flags
    ax_lib_proj_kernelname=`uname -s | tr 'A-Z' 'a-z'`
    ax_lib_proj_ismacos=no
    case "$ax_lib_proj_kernelname" in
      darwin*)
        ax_lib_proj_ismacos=yes
        ;;
    esac

    ax_lib_proj_hasbrew=no
    ax_lib_proj_homebrewprefix=
    if [[ "$ax_lib_proj_ismacos" = "yes" ]]; then
      AC_MSG_CHECKING(for homebrew)
      which brew
      if [[ $? -ne 0 ]]; then
        AC_MSG_RESULT([not found])
      else
        ax_lib_proj_hasbrew=yes  
        AC_MSG_RESULT([found])
      fi
  
      if [[ "$ax_lib_proj_hasbrew" = "yes" ]]; then
        AC_MSG_CHECKING([for homebrew prefix])
        ax_lib_proj_homebrewprefix=`brew --prefix`
        if [[ $? -ne 0 ]]; then
          ax_lib_proj_homebrewprefix=
          AC_MSG_RESULT([not found])
        else
          AC_MSG_RESULT($ax_lib_proj_homebrewprefix)
        fi
      fi
  
      if [[ "$ax_lib_proj_homebrewprefix" != "" ]]; then
        PROJ_LDFLAGS="-L$ax_lib_proj_lib"
        PROJ_LIBS="-lproj"
        PROJ_CFLAGS="-I$HOMEBREWPREFIX/include"
      fi
    fi
  fi

  CPPFLAGS="${CPPFLAGS} ${PROJ_CFLAGS}"
  LDFLAGS="${PROJ_LDFLAGS}"
  LIBS="${LIBS} ${PROJ_LIBS}"
  
  AC_CHECK_HEADERS(proj.h, [ax_lib_proj_proj6ok=yes], [ax_lib_proj_proj6ok=no])
  if [[ "$ax_lib_proj_proj6ok" = "yes" ]]; then
    AC_CHECK_LIB(proj, proj_trans, [
      PROJ_VARIANT=6
    ], [
      ax_lib_proj_proj6ok=no
    ])
    if [[ "$ax_lib_proj_proj6ok" = "no" -a "$ax_lib_proj_pkg_config_identified" = "yes" ]]; then
      AC_MSG_NOTICE([Could not identify PROJ.6])
    fi
  fi
  
  if  [[ "$ax_lib_proj_proj6ok" = "no" ]]; then
    AC_MSG_NOTICE([Trying to identify PROJ.4])
    AC_CHECK_HEADERS(projects.h, [ax_lib_proj_proj4ok=yes], [ax_lib_proj_proj4ok=no])
    if [[ "$ax_lib_proj_proj4ok" = "yes" ]]; then
      AC_CHECK_LIB([proj],
        [pj_transform],
        [ax_lib_proj_proj4ok=yes],
        [ax_lib_proj_proj4ok=no]
      )      
    fi
    if [[ "$ax_lib_proj_proj4ok" = "yes" ]]; then
      AC_RUN_IFELSE(
        [AC_LANG_PROGRAM(
          [[#include <projects.h>
            #include <stdio.h>
            #include <stdlib.h>]],
          [[printf("%d\n", (int)PJ_VERSION/100); exit(0);]])
        ],
        [AC_SUBST(PROJ_VERSION, [[`./conftest$EXEEXT`]])],
        [ax_lib_proj_proj4ok=no]
      )
      if [[ "$ax_lib_proj_proj4ok" = "yes" ]]; then
        AC_MSG_CHECKING([proj.4 version])
        PROJ_VERSION=`echo $PROJ_VERSION | egrep -e "^[[0-9]]+$"`
        if [[ "$PROJ_VERSION" = "" ]]; then
          AC_MSG_CHECKING([failed])
          ax_lib_proj_proj4ok=no
        else
          AC_MSG_RESULT([$PROJ_VERSION])
          if [[ "$PROJ_VERSION" -ge 5 ]]; then
            AC_MSG_NOTICE([Could not identify proj version <= 5])
            ax_lib_proj_proj4ok=no
          else
            PROJ_VARIANT=4
          fi
        fi
      fi
    fi
  fi

  AC_MSG_CHECKING([If PROJ could be identified])
  if [[ "$ax_lib_proj_proj4ok" = "no" -a "$ax_lib_proj_proj6ok" = "no" ]]; then
    AC_MSG_RESULT([No])
    AC_MSG_ERROR([Proj not found in standard search locations. Install proj.4/proj.6 library])  
    CPPFLAGS="${ax_lib_proj_save_CPPFLAGS}"
    LDFLAGS="${ax_lib_proj_save_LDFLAGS}"
    LIBS="${ax_lib_proj_save_LIBS}"
  else
    AC_MSG_RESULT([Yes])
    PROJ_FOUND=yes
    AC_MSG_NOTICE([PROJ variant: $PROJ_VARIANT])
    AC_MSG_NOTICE([PROJ cflags:  $PROJ_CFLAGS])
    AC_MSG_NOTICE([PROJ ldflags: $PROJ_LDFLAGS])
    AC_MSG_NOTICE([PROJ libs:    $PROJ_LIBS])
  fi  
else
  AC_MSG_NOTICE([PROJ check suppressed])
  PROJ_SUPPRESSED=yes
fi

if [[ "$ax_lib_proj_fun_arg" = "keepvar" ]]; then
  LIBS=$ax_lib_proj_save_LIBS
  CPPFLAGS="${ax_lib_proj_save_CPPFLAGS}"
  LDFLAGS="${ax_lib_proj_save_LDFLAGS}"
  LIBS="${ax_lib_proj_save_LIBS}"
fi

])


