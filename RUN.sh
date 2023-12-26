#! /bin/bash
#
# Generate the inofficial fablabnbg build of visicut.
# We basically pull a special version of liblasercut and build that wit the current master.
#
# Requires:
#   appimagecraft from https://appimage.github.io/appimagecraft/
#
# Tested in: docker run --rm -ti -v $PWD:/mnt ubuntu:22.04 bash; /mnt/RUN.sh
#    -> follow the instructions... and all deliverables should (somewhat unreliably) build.
#       you may need to manually repeat some of the distribute.sh calls.
#
# CAUTION:
# keep in sync with 
#   - https://github.com/t-oster/VisicutBuilder/blob/master/build.sh
#   - docker image registry.gitlab.com/t-oster/visicutbuildservice:/app/build.sh

visicut_tag=master
liblasercut_tag=master

depapt=
deperr=

check_installed() {
  # $1 is a command name, that we want to find in the PATH.
  #    or an existing absolute path name in the filesystem (dir or file)
  # $2 is an optional instructive error message if needed, or ""
  # $3 is an optional apt package name, if different from $1
  if [ -z "$(which $1)" -a ! -e "$1" ]; then
    test -n "$2" && deperr="$deperr
ERROR: $2
"
    test -z "$2$3" && depapt="$depapt $1"
    test -n "$3"   && depapt="$depapt $3"
  fi
}


check_installed wget
check_installed git
check_installed make
check_installed zip
check_installed unzip
check_installed checkinstall
check_installed makensis "" nsis
check_installed mvn "" maven
check_installed rsvg-convert "" librsvg2-bin
check_installed fusermount "" fuse
# not sure where this font is used, but it is seen in t-oster's Dockerfile:
check_installed /usr/share/fonts/truetype/noto/NotoSans-Medium.ttf "" fonts-noto-extra
check_installed appimagecraft "appimagecraft not installed! Try:
    sudo wget -O  /usr/local/bin/appimagecraft https://github.com/TheAssassin/appimagecraft/releases/download/continuous/appimagecraft-x86_64.AppImage
    sudo chmod +x /usr/local/bin/appimagecraft"


if [ -n "$depapt$deperr" ]; then
  if [ -n "$depapt" ]; then
    echo "ERROR: missing packages. Try:"
    echo "    sudo apt install$depapt"
  fi
  test -n "$deperr" && echo "$deperr"
  echo ""
  echo "... then try again..."
  exit 1
fi

if [ -z "$(git remote -v 2>&1 | grep VisiCut)" ]; then
  echo "ERROR: current directory is not a Visicut checkout. Try either"
  echo "  change directory to your checkout, if you have one,"
  echo "  or run e.g:"
  echo " 	git clone --recursive https://github.com/fablabnbg/VisiCut"
  echo " 	cd VisiCut"
  echo "  then retry:"
  echo "        bash $(readlink -f $0)"
  echo ""
  exit 1
fi

if [ -e /.dockerenv ]; then
  # Seen in https://github.com/AppImage/AppImageKit/issues/1027#issuecomment-1028232809
  export APPIMAGE_EXTRACT_AND_RUN=1
  # The mkdir calls in distribute.sh linux-checkinstall silently fail in docker. Do them ahead of time ... that helps.
  mkdir -p /usr/share/visicut/{inkscape_extension,illustrator_script}
  mkdir -p /usr/share/pixmaps
  cp -r distribute/files/* /usr/share/visicut/	# so that all directories get created...
fi

git checkout $visicut_tag
pushd LibLaserCut
git checkout $liblasercut_tag
llc_commit=$(git describe --tags | sed -e 's/.*-g//')
popd
echo "Last commit of LibLaserCut is $llc_commit"
echo "Last commit of VisiCut is $(git describe --tags)"

export VERSION="$(git describe --tags | sed -e "s/-g/-jw-l$llc_commit-g/")"

echo "press Enter to continue with VERSION=$VERSION"
echo "or enter something different..."
read a
test -n "$a" && VERSION=$a

propfiles=src/main/resources/de/thomas_oster/visicut/gui/resources/VisicutApp*.properties
sed -i -e "s/^Application.version =.*\$/Application.version = $VERSION/" $propfiles
./generatesplash.sh
make dist
sed -i -e "s/^Application.version =.*\$/Application.version =/" $propfiles	# revert how it is in git ...

env NO_BUILD=1 ./distribute/distribute.sh windows-nsis
env NO_BUILD=1 ./distribute/distribute.sh macos-bundle
env NO_BUILD=1 ./distribute/distribute.sh linux-checkinstall
env NO_BUILD=1 ./distribute/distribute.sh linux-appimage
ls -la VisiCut-*.exe VisiCutMac-*.zip visicut*.deb VisiCut*.AppImage

echo ""
echo "during development, you can use:"
jar="$(echo target/visicut-*-full.jar)"
echo "    make; java -Xms256m -Xmx2048m -jar $jar"

