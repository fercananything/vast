#!/usr/bin/env bash
#
# This shell script is needed to correctly compile pgplot-related programs on stupid Ubuntu where,
# by some strange reason, pgplot-related programs segfault if compiled directly using make...
#
# This script is intended to be started automatically from the Makefile
#

#################################
# Set the safe locale that should be available on any POSIX system
LC_ALL=C
LANGUAGE=C
export LANGUAGE LC_ALL
#################################

# For compatibility with BSD Make:
# if the script is called by GNU Make MFLAGS="-w" will be set that confuses BSD Make.
export MAKEFLAGS=""
export MFLAGS=""
#

VAST_DIR=$PWD
TARGET_DIR=$VAST_DIR/lib
#LIBRARY_SOURCE=$VAST_DIR/src/cfitsio
LIBRARY_SOURCE=$VAST_DIR/src/cfitsio-3.49
FITSVERIFY_SOURCE=$VAST_DIR/src/fitsverify

echo " "
echo -e "Starting script \033[01;32m$0 $1\033[00m"


if [ "$1" = "clean" ];then
 echo -e "\033[01;34mRemoving the local copy of CFITSIO library\033[00m"
 cd $LIBRARY_SOURCE
 make clean
 make distclean
 rm -f *.pdf *.ps
 #
 if [ -f $VAST_DIR/util/listhead ];then
  rm -f $VAST_DIR/util/listhead
 fi
 #
 if [ -f $VAST_DIR/util/modhead ];then
  rm -f $VAST_DIR/util/modhead
 fi
 #
 if [ -f $VAST_DIR/util/imarith ];then
  rm -f $VAST_DIR/util/imarith
 fi
 #
 echo "Script $0 is done."
 echo " "
 exit
fi

C_COMPILER=`lib/find_gcc_compiler.sh`

echo -e "\033[01;34mCompiling CFITSIO library\033[00m"
echo "Using C compiler: $C_COMPILER" 

COMPILATION_ERROR=0

# Compile the library
cd $LIBRARY_SOURCE
make clean
./configure --prefix=$TARGET_DIR --disable-curl
if [ $? -ne 0 ];then
 COMPILATION_ERROR=1
fi
if [ $COMPILATION_ERROR -eq 0 ];then
 make -j9
fi
if [ $? -ne 0 ];then
 COMPILATION_ERROR=1
fi

# moved down to make sure fitscopy is statically linked
if [ $COMPILATION_ERROR -eq 0 ];then
 # fitscopy may get dynamically linked with this
 #make fitscopy
 $C_COMPILER -o ../../util/fitscopy fitscopy.c libcfitsio.a -lm
fi

# Compile funpack.c
if [ $COMPILATION_ERROR -eq 0 ];then
 $C_COMPILER -c -o fpackutil.o fpackutil.c
 if [ $? -ne 0 ];then
  echo "ERROR compiling fpackutil.o" 1>&2
  COMPILATION_ERROR=1
 fi
 $C_COMPILER -c -o funpack.o funpack.c
 if [ $? -ne 0 ];then
  echo "ERROR compiling funpack.o" 1>&2
  COMPILATION_ERROR=1
 fi
 $C_COMPILER -o ../../util/funpack funpack.o fpackutil.o libcfitsio.a -lm
 if [ $? -ne 0 ];then
  echo "ERROR compiling funpack" 1>&2
  COMPILATION_ERROR=1
 fi
fi


if [ $COMPILATION_ERROR -eq 0 ];then
 #cp -f fitscopy $VAST_DIR/util
 #cp -f funpack $VAST_DIR/util
 cp -f libcfitsio.a $TARGET_DIR/libcfitsio.a
 #cp -f fitsio.h longnam.h $VAST_DIR/src
 # we want 'splint' tool to ignore fitsio.h
 echo "#ifndef S_SPLINT_S" > $VAST_DIR/src/fitsio.h
 cat fitsio.h >> $VAST_DIR/src/fitsio.h
 echo "#endif" >> $VAST_DIR/src/fitsio.h
 cp -f longnam.h $VAST_DIR/src
 make clean
fi



cd $VAST_DIR

# Compile FITSVERIFY - A FITS File Format-Verification Tool
if [ $COMPILATION_ERROR -eq 0 ];then
 cd $FITSVERIFY_SOURCE
 $C_COMPILER -o $TARGET_DIR/fitsverify ftverify.c fvrf_data.c fvrf_file.c fvrf_head.c fvrf_key.c fvrf_misc.c -DSTANDALONE -I$LIBRARY_SOURCE  -L$TARGET_DIR -lcfitsio -lm #-lnsl
 if [ $? -ne 0 ];then
  echo "ERROR compiling fitsverify" 1>&2
  COMPILATION_ERROR=1
 fi
 cd $VAST_DIR
fi

# Compile listhead
if [ $COMPILATION_ERROR -eq 0 ];then
 $C_COMPILER -o util/listhead src/listhead.c $TARGET_DIR/libcfitsio.a -lm
 if [ $? -ne 0 ];then
  echo "ERROR compiling listhead" 1>&2
  COMPILATION_ERROR=1
 fi
fi

# Compile modhead
if [ $COMPILATION_ERROR -eq 0 ];then
 $C_COMPILER -o util/modhead src/modhead.c $TARGET_DIR/libcfitsio.a -lm
 if [ $? -ne 0 ];then
  echo "ERROR compiling modhead" 1>&2
  COMPILATION_ERROR=1
 fi
fi

# Compile imarith
if [ $COMPILATION_ERROR -eq 0 ];then
 $C_COMPILER -o util/imarith src/imarith.c $TARGET_DIR/libcfitsio.a -lm
 if [ $? -ne 0 ];then
  echo "ERROR compiling imarith" 1>&2
  COMPILATION_ERROR=1
 fi
fi


# Test if executable files were actually created?
if [ $COMPILATION_ERROR -eq 0 ];then
echo -n "Checking library files:   "
 for TEST_FILE in $TARGET_DIR/libcfitsio.a $TARGET_DIR/fitsverify util/listhead util/modhead util/imarith util/fitscopy util/funpack ;do
  echo -n "$TEST_FILE - "
  if [ ! -f $TEST_FILE ];then
   COMPILATION_ERROR=1
   echo -ne "\033[01;31mERROR\033[00m,   "
  else
   echo -ne "\033[01;32mOK\033[00m,   "
  fi
 done
 echo "done!"
fi

if [ $COMPILATION_ERROR -eq 1 ];then
 echo -e "\033[01;31mCOMPILATION ERROR\033[00m"
 exit 1
fi

echo -e "\033[01;34mFinished compiling CFITSIO library\033[00m"
echo " "
