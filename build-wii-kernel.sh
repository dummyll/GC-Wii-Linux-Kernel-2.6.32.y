#!/bin/bash
#
# Linux Shell Script For Compiling Wii Linux Kernels
#
# Written by DeltaResero <deltaresero@zoho.com>
#


#Set defaults and checks if arch is supported by this script 
clear
echo "This basic script is meant as a way to help with cross compiling"
echo "GameCube and Wii Kernels.  While this isn't very robust, it should"
echo -e "suffice for most basic compilations.\n"

echo "Compiling a Kernel usually requires the following dependencies at minimal:"
echo "advancecomp (advdef), autoconfig, automake, bash, build-essential,"
echo "busybox, bzip2, fakeroot, gcc, g++, gizp,libnurses5-dev, strip."
echo "While there are other dependencies, these are the most common ones."
echo "If any are missing, it's highly recommended that this script be stopped"
echo -e "and these dependency packages be installed before continuing.\n"

useConfig=''
MACHINE_TYPE=`uname -m`

if [[ ${MACHINE_TYPE} != 'x86_32'&& ${MACHINE_TYPE} != 'x86_64' && ${MACHINE_TYPE} != 'ppc' ]]; then
  echo "ARCH: Unsupported -" $MACHINE_TYPE
  echo "Quitting script..."
  exit 0
fi

#Attempts to get user to select a base configuration to start with
while :
do
  echo "Enter a numerical value corresponding to the configuration to be used"
  echo "(Remember to edit the platform dts 'bootags' to correspond to the build type)"
  echo "1) Isobel's  - Default / With Modules (MINI)"
  echo "2) DeltaResero's - Minimalist / No Modules (MINI)"
  echo "3) DeltaResero's - Minimalist / No Modules (IOS)"
  echo "4) Use Existing (.config) Configuration"
  echo "5) Quit Script"
  echo -n "Answer: "
  read opt
  case $opt in
    1) echo "Selecting config: wii_defconfig"
       useConfig='wii_defconfig'
       break;;
    2) echo "Selecting config: wii-mini-mode_defconfig"
       useConfig='wii-mini-mode_defconfig'
       break;;
    3) echo "Selecting config: wii-ios-mode_defconfig"
       useConfig='wii-ios-mode_defconfig'
       break;;
    4) echo "Selecting config: .config"
       useConfig='.config'
       break;;
    5) echo "Quitting script..."
       exit 0;;
    *) echo -e "\n$opt is an invalid option."
       echo "Please select option between 1-5 only"
       echo "Press [enter] key to continue. . ."
       read enterKey
       clear;;
esac
done
#Find number of processors for setting number of parallel jobs
numProcessors=$(grep -c ^processor /proc/cpuinfo)
echo "Detected number of processors:" ${numProcessors}

if [ ${MACHINE_TYPE} == 'x86_32' ]; then
  MACHINE_TYPE='Intel 80386'
  echo "ARCH: 32-bit -" ${MACHINE_TYPE}
  export LD_LIBRARY_PATH=H-i686-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/lib

  if [ ${useConfig} != '.config' ]; then
    make ${useConfig} ARCH=powerpc CROSS_COMPILE=H-i686-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/powerpc-linux-
  fi

  make menuconfig ARCH=powerpc CROSS_COMPILE=H-i686-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/powerpc-linux-
  make clean ARCH=powerpc CROSS_COMPILE=H-i686-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/powerpc-linux-
  make -j${numProcessors} ARCH=powerpc CROSS_COMPILE=H-i686-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/powerpc-linux-


elif [ ${MACHINE_TYPE} == 'x86_64' ]; then
  MACHINE_TYPE='x86-64'
  echo "ARCH: 64-bit -" ${MACHINE_TYPE}
  export LD_LIBRARY_PATH=H-x86_64-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/

  if [ ${useConfig} != '.config' ]; then
    make ${useConfig} ARCH=powerpc CROSS_COMPILE=H-x86_64-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/powerpc-linux-
  fi

  make menuconfig ARCH=powerpc CROSS_COMPILE=H-i686-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/powerpc-linux-
  make clean ARCH=powerpc CROSS_COMPILE=H-x86_64-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/powerpc-linux-
  make -j${numProcessors} ARCH=powerpc CROSS_COMPILE=H-x86_64-pc-linux-gnu/cross-powerpc-linux-uclibc/usr/bin/powerpc-linux-


else # Arch must be 32 bit powerpc as it's the only choice left
  MACHINE_TYPE='PowerPC'
  echo "ARCH: 32-bit -" ${MACHINE_TYPE}

  if [ ${useConfig} != '.config' ]; then
    make ${useConfig}
  fi

  make clean
  make menuconfig
  make -j${numProcessors}
fi

#Sets modules and temp folder paths
TEMP_DIRECTORY='../modules'
MOD_DIRECTORY='modules'

#Checks if the temporary directory exist (quits if it does already)
if [ -d "$TEMP_DIRECTORY" ]; then
  echo "Error: Temp directory already exist at -" $TEMP_DIRECTORY
  echo "Script quitting..."
  echo "Manually run: 'find -name '*.ko' -exec cp -av {} ../modules \;'"
  echo "to copy files to modules folder a level up.  You may have to"
  echo "create a modules folder with 'mkdir ../modules' prior..."
  exit
fi

#Creates the temporary directory
echo "Creating temp folder:" $TEMP_DIRECTORY
mkdir $TEMP_DIRECTORY

#Removes modules directory if it already exist
if [ -d "$MOD_DIRECTORY" ]; then
  echo "Removing existing modules folder in current directory..."
  rm -R $MOD_DIRECTORY
fi

#Checks for modules and places them in a temp folder and then moves them to the modules folder
find -name '*.ko' -exec cp -av {} $TEMP_DIRECTORY \;
echo -e "Moving temp modules folder ("$TEMP_DIRECTORY") into current directory...\n"
mv $TEMP_DIRECTORY .

#Strip zImage even farther (if possible)
strip=./sstrip
zImageFile=arch/powerpc/boot/zImage
zImageInitrdFile=arch/powerpc/boot/zImage.initrd

#Check for already existing local sstrip build
if [ -f $strip ]; then
  echo "Found sstrip..."
else
  echo "Building sstrip..."
  make -C super-strip
  mv super-strip/sstrip sstrip
fi

#checks if sstrip is executable
if [ -x "$strip" ]; then
  echo "The sstrip binary is executable..."
else
  echo "Attempting to make sstrip executable..."
  chmod +x sstrip
fi


#Checks if sstrip is same arch as host
if [ $(file $strip | grep -ci ${MACHINE_TYPE}) == '1' ]; then
  echo "sstrip is correct arch (same as host machine)..."
else
    echo "sstrip is not correct arch (different than host machine)..."
    echo "Removing sstrip..."
    rm sstrip

    echo "Building sstrip..."
    make -C super-strip
    mv super-strip/sstrip sstrip

    echo "Attempting to make sstrip executable..."
    chmod +x sstrip

    echo "Cleaning sstrip build files..."
    make clean -C super-strip
fi

#Checks for zImage and runs sstrip on it
if [ -f $zImageFile ]; then
  echo "Stripping zImage..."
  ./sstrip -z $zImageFile

#Checks for zImage.initrd and runs sstrip on it
elif [ -f $zImageInitrdFile ]; then
  echo "Stripping zImage.initrd"
  ./sstrip -z $zImageInitrdFile
else #No zImage (broken build)
  echo "Error, zImage (Kernel) not found!"
  echo "Quitting script..."
  exit 1
fi

#Script is finished (everything should have been successful upon reaching here
echo -e "Done! (Check to see if there were any errors above)\n"
echo "The binary (zImage) can be found in: 'arch/powerpc/boot'"
echo "Modules (if any) should be located in the folder:" $MOD_DIRECTORY
echo -e "\nWARNING: DO NOT STRIP KERNEL ELF WITH STRIP, IT WAS STRIPPED WITH SSTRIP"
echo "(Stripping the zImage with strip will result in corruption!)"
exit 0
#
#
# Requires a buildroot PowerPC cross compiler for x86 systems
# See the tool at http://www.gc-linux.org/wiki/Building_a_GameCube_Linux_Kernel_%28ARCH%3Dpowerpc%29
#
