#FROM ubuntu:18.04
FROM linuxmintd/mint20.2-amd64

#AS QUARTUS:2020.2

MAINTAINER Leon Woestenberg <leon@sidebranch.com>

# Building the Docker image
#
# A HTTP(S) host must serve out $QUARTUS_TAR_FILE
# An easy way is to run a temporary server from within the containing directory
# python3 -m http.server 8000
#
# build with
# docker build --network=host -t QUARTUS .
#
# If "Downloading and extracting from http://..." fails, check if the HTTP server
# is accessible.
#
# You can override the ARG default (see below) on the command line, or adapt this Dockerfile.
# docker build --network=host --build-arg QUARTUS_TAR_HOST=http://host:port -t QUARTUS .
#
# Quartus Prime Pro only supports Cyclone 10 GX for free but requires (additional) licenses for Arria 10 and higher class devices
ARG QUARTUS_TAR_HOST="http://localhost:8000"
ARG QUARTUS_TAR_FILE="Quartus-pro-21.2.0.72-linux-complete.tar"
ARG QUARTUS_VERSION="21.2"

# Quartus Prime Standard only supports Cyclone 10 LP and lower class devices
#ARG QUARTUS_TAR_HOST="https://download.altera.com"
#ARG QUARTUS_TAR_FILE="akdlm/software/acdsinst/20.1std.1/720/ib_tar/Quartus-20.1.1.720-linux-complete.tar
#ARG QUARTUS_VERSION="20.1.1.720"

#ARG PETALINUX_RUN_FILE="petalinux-v2020.2-final-installer.run"

# Running the Docker image in a Docker container
#
# docker run -ti --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
# -v $PWD:/home/quartus/project -w /home/quartus/project quartus:latest
#
# The current directory on the host is mounted as read-write in the container.
# The license file of the host is mounted read-only. See the --mac-address= flag for docker run.

# Set BASH as the default shell
RUN echo "dash dash/sh boolean false" | debconf-set-selections

#RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true dpkg-reconfigure dash

ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# If apt-get install were in a separate RUN instruction, then it would reuse a layer added by apt-get update,
# which could had been created a long time ago.

# Update the apt-repo and upgrade and re-update while the apt-cache may be invalid
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  nano vim software-properties-common locales apt-utils

# Generate and configure the character set encoding to en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

RUN locale-gen --purge en_US.UTF-8
RUN echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' > /etc/default/locale

#install dependences for:
# * downloading QUARTUS: wget
# * xsim: build-essential, which contains gcc and make)
# * MIG tool: libglib2.0-0 libsm6 libxi6 libxrender1 libxrandr2 libfreetype6 libfontconfig
# * CI git
#
# * PetaLinux: expect ... libncurses5-dev 
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
  wget \
  build-essential \
  libglib2.0-0 \
  libsm6 \
  libxi6 \
  libxrender1 \
  libxrandr2 \
  libfreetype6 \
  libfontconfig \
  libgtk3.0 \
  git \
  \
  expect gawk net-tools xterm autoconf libtool \
  texinfo zlib1g-dev gcc-multilib libncurses5-dev \
  \
  && ldconfig

#RUN DEBIAN_FRONTEND=noninteractive \
#  && apt-get clean \
#  && apt-get autoremove \
#  && rm -rf /var/lib/apt/lists/* \
#  && ldconfig

# download and run the install
RUN echo "Downloading and extracting ${QUARTUS_TAR_FILE} from ${QUARTUS_TAR_HOST}" && \
  wget -O- ${QUARTUS_TAR_HOST}/${QUARTUS_TAR_FILE} -q | \
  tar xvf -

#make a QUARTUS user
RUN adduser --disabled-password --gecos '' quartus

RUN mkdir -p /etc/sudoers.d
RUN echo >/etc/sudoers.d/quartus 'quartus ALL = (ALL) NOPASSWD: SETENV: ALL'

RUN mkdir -p /opt/quartus
#RUN cd components && /setup.sh --mode unattended --accept_eula 1 --installdir /opt/quartus
RUN cd components && ./QuartusProSetup-21.2.0.72-linux.run --mode unattended --accept_eula 1 --installdir /opt/quartus

#
#  --mode unattended \
#  --unattendedmodeui none \
#  --installdir $INSTALLDIR \
#  --disable-components quartus_help,modelsim_ase,modelsim_ae \
#  --accept_eula 1
#

#RUN -p /opt/intel && \ 

RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 && apt-get update && apt-get install -y \
  libxt6:i386 libxtst6:i386 expat:i386 \
    fontconfig:i386 libfreetype6:i386 libexpat1:i386 libc6:i386 \
    libgtk-3-0:i386 libcanberra0:i386 libice6:i386 libsm6:i386 \
    libncurses5:i386 zlib1g:i386 libx11-6:i386 libxau6:i386 \
    libxdmcp6:i386 libxext6:i386 libxft2:i386 libxrender1:i386

#    build-essential gcc-multilib g++-multilib lib32z1 lib32stdc++6 lib32gcc1 \

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y libncurses5

RUN find /opt/quartus -type d | xargs -L1 chmod ugo+rwx

# remaining build steps are run as this user; this is also the default user when the image is run.
USER quartus
WORKDIR /home/quartus

RUN echo "alias quartus='/opt/quartus/quartus/bin/quartus --64bit'" >>~/.bashrc
RUN echo "alias vsim='/opt/quartus/modelsim_ase/bin/vsim'" >>~/.bashrc
RUN echo "export PATH=$PATH:/opt/quartus/modelsim_ase/bin" >>~/.bashrc

ADD .modelsim /home/quartus/

# https://vhdlwhiz.com/modelsim-quartus-prime-lite-ubuntu-20-04/
# https://gist.github.com/PrieureDeSion/e2c0945cc78006b00d4206846bdb7657

#If you want to launch modelsim from Quartus, you have to edit quartus/adm/qenv.sh in the following way:
#
#    find the line export LD_LIBRARY_PATH=$QUARTUS_BINDIR:$LD_LIBRARY_PATH
#    prepend it with the path to a folder containing libfreetype 32-bit shared objects. So if you followed the instructions above, it should look like this: export LD_LIBRARY_PATH=/opt/modelsim_ase/lib32:$QUARTUS_BINDIR:$LD_LIBRARY_PATH


# This list is taken from 
#RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 && \
#apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#iproute2 gawk python3 python build-essential gcc git make net-tools libncurses5-dev tftpd zlib1g-dev libssl-dev flex bison libselinux1 gnupg \
#wget git-core diffstat chrpath socat xterm autoconf libtool tar unzip texinfo zlib1g-dev gcc-multilib automake zlib1g:i386 screen pax gzip cpio \
#python3-pip python3-pexpect xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev pylint3
