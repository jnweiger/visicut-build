#!/bin/sh
#
# Generate the inofficial fablabnbg build of visicut.
# We basically pull a special version of liblasercut and build that wit the current master.
#
# Requires:
#   appimagecraft from https://appimage.github.io/appimagecraft/

visicut_tag=master
liblasercut_tag=master

if [ -z "$(which appimagecraft)" ]; then
  echo "ERROR: appimagecraft not installed! Download"
  echo "        https://github.com/TheAssassin/appimagecraft/releases/download/continuous/appimagecraft-x86_64.AppImage"
  echo "        and install it in your PATH as appimagecraft"
  exit 1
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

propfile=src/main/resources/de/thomas_oster/visicut/gui/resources/VisicutApp.properties
sed -i -e "s/^Application.version =.*\$/Application.version = $VERSION/" $propfile
./generatesplash.sh
make dist
sed -i -e "s/^Application.version =.*\$/Application.version =/" $propfile	# that how it is in git ...

env NO_BUILD=1 ./distribute/distribute.sh windows-nsis
env NO_BUILD=1 ./distribute/distribute.sh macos-bundle
env NO_BUILD=1 ./distribute/distribute.sh linux-checkinstall
env NO_BUILD=1 ./distribute/distribute.sh linux-appimage
ls -la VisiCut-*.exe VisiCutMac-*.zip visicut*.deb VisiCut*.AppImage

