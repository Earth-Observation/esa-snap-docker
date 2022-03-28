# Ubuntu 20.04 (focal)
# https://hub.docker.com/_/ubuntu/?tab=tags&name=focal
ARG ROOT_CONTAINER=ubuntu:focal

FROM $ROOT_CONTAINER


LABEL authors="Islam Mansour"
LABEL maintainer="me@imansour.net"

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"



# Fix: https://github.com/hadolint/hadolint/wiki/DL4006
# Fix: https://github.com/koalaman/shellcheck/wiki/SC3014
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update --yes && \
    # - apt-get upgrade is run to patch known vulnerabilities in apt-get packages as
    #   the ubuntu base image is rebuilt too seldom sometimes (less than once a month)
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    ca-certificates \
    fonts-liberation \
    locales \
    # - pandoc is used to convert notebooks to html files
    #   it's not present in arm64 ubuntu image, so we install it here
    pandoc \
    # - run-one - a wrapper script that runs no more
    #   than one unique  instance  of  some  command with a unique set of arguments,
    #   we use `run-one-constantly` to support `RESTARTABLE` option
    run-one \
    sudo \
    # - tini is installed as a helpful container entrypoint that reaps zombie
    #   processes and such of the actual executable we want to start, see
    #   https://github.com/krallin/tini#why-tini for details.
    tini \
    build-essential \
    libgfortran5 \
    git \
    vim \
    wget \
    zip \
    wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH="${CONDA_DIR}/bin:${PATH}" \
    HOME="/home/${NB_USER}"

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
# hadolint ignore=SC2016
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
    # Add call to conda init script see https://stackoverflow.com/a/58081608/4413446
    echo 'eval "$(command conda shell.bash hook 2> /dev/null)"' >> /etc/skel/.bashrc

# Create NB_USER with name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    mkdir -p "${CONDA_DIR}" && \
    chown "${NB_USER}:${NB_GID}" "${CONDA_DIR}" && \
    chmod g+w /etc/passwd && \
    fix-permissions "${HOME}" && \
    fix-permissions "${CONDA_DIR}"

USER ${NB_UID}
ARG PYTHON_VERSION=default

# Setup work directory for backward-compatibility
RUN mkdir "/home/${NB_USER}/work" && \
    fix-permissions "/home/${NB_USER}"

# Install conda as jovyan and check the sha256 sum provided on the download site
WORKDIR /tmp

# CONDA_MIRROR is a mirror prefix to speed up downloading
# For example, people from mainland China could set it as
# https://mirrors.tuna.tsinghua.edu.cn/github-release/conda-forge/miniforge/LatestRelease
ARG CONDA_MIRROR=https://github.com/conda-forge/miniforge/releases/latest/download

# ---- Miniforge installer ----
# Check https://github.com/conda-forge/miniforge/releases
# Package Manager and Python implementation to use (https://github.com/conda-forge/miniforge)
# We're using Mambaforge installer, possible options:
# - conda only: either Miniforge3 to use Python or Miniforge-pypy3 to use PyPy
# - conda + mamba: either Mambaforge to use Python or Mambaforge-pypy3 to use PyPy
# Installation: conda, mamba, pip
RUN set -x && \
    # Miniforge installer
    miniforge_arch=$(uname -m) && \
    miniforge_installer="Mambaforge-Linux-${miniforge_arch}.sh" && \
    wget --quiet "${CONDA_MIRROR}/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    if [[ "${PYTHON_VERSION}" != "default" ]]; then mamba install --quiet --yes python="${PYTHON_VERSION}"; fi && \
    # Pin major.minor version of python
    mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Using conda to update all packages: https://github.com/mamba-org/mamba/issues/1092
    conda update --all --quiet --yes && \
    conda clean --all -f -y && \
    rm -rf "/home/${NB_USER}/.cache/yarn" && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

# Using fixed version of mamba in arm, because the latest one has problems with arm under qemu
# See: https://github.com/jupyter/docker-stacks/issues/1539
RUN set -x && \
    arch=$(uname -m) && \
    if [ "${arch}" == "aarch64" ]; then \
    mamba install --quiet --yes \
    'mamba<0.18' && \
    mamba clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"; \
    fi;

# Install Jupyter Notebook, Lab, and Hub
# Generate a notebook server config
# Cleanup temporary files
# Correct permissions
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change
RUN mamba install --quiet --yes \
    'notebook' \
    'jupyterhub' \
    'jupyterlab' && \
    mamba clean --all -f -y && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    jupyter lab clean && \
    rm -rf "/home/${NB_USER}/.cache/yarn" && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"


USER root

# Install SNAP

ENV PATH=/usr/local/openresty/nginx/sbin:$PATH
ENV LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:${CONDA_DIR}/lib

# SNAP wants the current folder '.' included in LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH ".:$LD_LIBRARY_PATH"
RUN ln -fs ${CONDA_DIR}/bin/python3 /usr/bin/python3

# install SNAPPY
RUN apt-get update --yes && \
    apt-get install default-jdk maven nano --yes && \
    apt-get clean && rm -rf /var/lib/apt/lists/* 

ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64/"
RUN echo $(javac -version)

ENV SNAP_HOME=/opt/snap 
ENV SNAP_USER=${SNAP_HOME}/.snap 
RUN echo SNAP_USER: ${SNAP_USER}

RUN mkdir -p "${SNAP_HOME}" && \
    chown "${NB_USER}:${NB_GID}" "${SNAP_HOME}" && \
    mkdir -p "${SNAP_USER}" && \
    chown "${NB_USER}:${NB_GID}" "${SNAP_USER}" && \
    mkdir -p "${SNAP_HOME}/../snap-src" && \
    chown "${NB_USER}:${NB_GID}" "${SNAP_HOME}/../snap-src" && \
    fix-permissions "${SNAP_HOME}" && \
    fix-permissions "${SNAP_HOME}" && \
    fix-permissions "${SNAP_HOME}/../snap-src"

USER ${NB_UID}
#RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1
COPY snap/install.sh ${SNAP_HOME}/../snap-src/install.sh
COPY snap/response.varfile ${SNAP_HOME}/../snap-src/response.varfile
RUN bash ${SNAP_HOME}/../snap-src/install.sh

COPY snap/post-install.sh ${SNAP_HOME}/../snap-src/post-install.sh
RUN bash ${SNAP_HOME}/../snap-src/post-install.sh

COPY snap/about.py ${SNAP_HOME}/../snap-src/about.py
RUN python -c 'from esasnappy import ProductIO'
RUN python ${SNAP_HOME}/../snap-src/about.py

RUN sed -i -e 's/-Xmx*.*/-Xmx16G/g' ${SNAP_HOME}/bin/gpt.vmoptions && \
    sed -i -e 's/-Xmx*.*G/-Xmx16G/g' ${SNAP_HOME}/etc/snap.conf

RUN python ${SNAP_HOME}/../snap-src/about.py


USER ${NB_UID}

WORKDIR ${HOME}

