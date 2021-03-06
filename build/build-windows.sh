#!/bin/sh

export LANG=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

ruby_versions="2.2.4 2.3.1 2.4.0 2.5.0"
export RUBY_CC_VERSION="2.2.4:2.3.1:2.4.0:2.5.0"

N_CPUS=$(grep '^processor' /proc/cpuinfo | wc -l)
export MAKE_N_JOBS=${N_CPUS}

export RUBYLIB="$(pwd)/pkg-config/lib:$(pwd)/native-package-installer/lib"

export PATH="${HOME}/.cargo/bin:${PATH}"

wine_home="z:/home/vagrant"
wine_rcairo="${wine_home}/rcairo"
wine_ruby_gnome2="${wine_home}/ruby-gnome2"
bin_dir="vendor/local/bin"
WINEPATH="${wine_rcairo}/${bin_dir}"
WINEPATH="${WINEPATH};${wine_ruby_gnome2}/glib2/${bin_dir}"
WINEPATH="${WINEPATH};${wine_ruby_gnome2}/gdk_pixbuf2/${bin_dir}"
WINEPATH="${WINEPATH};${wine_ruby_gnome2}/pango/${bin_dir}"
WINEPATH="${WINEPATH};${wine_ruby_gnome2}/pango/tmp/windows/graphene/graphene-1.8.2/build/src"
WINEPATH="${WINEPATH};${wine_ruby_gnome2}/atk/${bin_dir}"
WINEPATH="${WINEPATH};${wine_ruby_gnome2}/gtk2/${bin_dir}"
WINEPATH="${WINEPATH};${wine_ruby_gnome2}/gdk3/${bin_dir}"
WINEPATH="${WINEPATH};${wine_ruby_gnome2}/clutter/tmp/windows/json-glib/json-glib-1.4.2/build/json-glib"
export WINEPATH

run()
{
  "$@"
  if [ $? -ne 0 ]; then
    echo "Failed $@"
    exit 1
  fi
}

if [ ! -f ~/setup.timestamp ]; then
  run sudo rm -rf /etc/udev/rules.d/70-persistent-net.rules/
  run sudo sed -i'' -e 's,http://us,http://jp,g' /etc/apt/sources.list
  run sudo dpkg --add-architecture i386
  run sudo apt-get update

  echo ttf-mscorefonts-installer \
       msttcorefonts/accepted-mscorefonts-eula \
       select true | \
    run sudo debconf-set-selections

  run \
    sudo apt-get install -y -V \
    git \
    ruby \
    ruby-dev \
    build-essential \
    pkg-config \
    autoconf \
    libtool \
    gettext \
    intltool \
    gtk-doc-tools \
    libffi-dev \
    libglib2.0-dev \
    libgdk-pixbuf2.0-dev \
    gobject-introspection \
    libgtk2.0-bin \
    gtk-3-examples \
    libgtk-3-dev \
    flex \
    bison \
    gperf \
    libxml2-utils \
    python-dev \
    python-pip \
    wine-stable \
    wine-binfmt \
    mingw-w64 \
    mingw-w64-tools \
    cmake \
    valac \
    libmount-dev \
    python3-pip

  # Enable me when WebKitGTK+ supports Windows.
  # run sudo update-alternatives --set \
  #     ${BUILD_HOST}-gcc /usr/bin/${BUILD_HOST}-gcc-posix
  # run sudo update-alternatives --set \
  #     ${BUILD_HOST}-g++ /usr/bin/${BUILD_HOST}-g++-posix

  run sudo pip3 install jsmin meson ninja

  run curl https://sh.rustup.rs -sSf > rustup.sh
  run chmod +x rustup.sh
  run ./rustup.sh -y
  run rm rustup.sh
  if [ ${BUILD_HOST} = "x86_64-w64-mingw32" ]; then
    run rustup target add x86_64-pc-windows-gnu
  else
    run rustup target add i686-pc-windows-gnu
  fi

  run git clone file:///pkg-config/.git
  run git clone file:///native-package-installer/.git
  run git clone file:///rcairo/.git rcairo
  run git clone file:///ruby-gnome2/.git ruby-gnome2

  run sudo gem install --no-document \
      rake \
      bundler \
      pkg-config \
      native-package-installer \
      rake-compiler \
      mechanize \
      packnga

  if [ ! -d ~/.wine/ ]; then
    run wineboot
  fi

  run wget https://www.opengl.org/registry/api/GL/glext.h
  run sudo install glext.h /usr/share/mingw-w64/include/GL/
  run rm -f glext.h

  if ! grep -q GL/glext /usr/share/mingw-w64/include/GL/gl.h; then
    if [ "${BUILD_HOST}" = "i686-w64-mingw32" ]; then
      cat <<EOF > /tmp/insert.txt

#include <GL/glext.h>

EOF
    else
      cat <<EOF > /tmp/insert.txt

typedef ptrdiff_t GLintptr;
typedef ptrdiff_t GLsizeiptr;
typedef char GLchar;
#include <GL/glext.h>

EOF
    fi
    run sudo sed -i'' -e '/typedef void GLvoid;/ r /tmp/insert.txt' \
        /usr/share/mingw-w64/include/GL/gl.h
    run rm -f /tmp/insert.txt
  fi

  run sudo ln -s /usr/include/KHR/ /usr/i686-w64-mingw32/include/
  run sudo ln -s /usr/include/KHR/ /usr/x86_64-w64-mingw32/include/

  run touch ~/setup.timestamp
fi

if [ ! -f ~/rake-compiler.timestamp ]; then
  sudo chown -R "${USER}:${USER}" /var/lib/gems

  for ruby_version in ${ruby_versions}; do
    run rake-compiler cross-ruby HOST="${BUILD_HOST}" VERSION="${ruby_version}"
  done

  run touch ~/rake-compiler.timestamp
fi

if [ ! -f ~/native.timestamp ]; then
  run cd ~/rcairo
  run git pull --rebase
  run rake windows:gcc:dll:bundle windows:zlib:build

  run cd ~/ruby-gnome2
  run git pull --rebase

  run cd ~/ruby-gnome2/glib2
  run rake native:build windows:build

  run cd ~/ruby-gnome2/gobject-introspection
  run rake native:build

  run touch ~/native.timestamp
fi

if [ ! -f ~/rcairo.timestamp ]; then
  run cd ~/rcairo
  run git pull --rebase
  run rake windows:build
  run rake cross compile native

  run touch ~/rcairo.timestamp
fi

run cd ~/ruby-gnome2
run git pull --rebase
run rake gem:windows:clean:gem gem:windows:build

run mkdir -p /vagrant/pkg
run cp */pkg/*.gem /vagrant/pkg/
