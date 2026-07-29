# Triton version to build the agent for. TRITON_VERSION is the NGC tag (YY.MM);
# the agent is compiled against the matching triton core/common release branch
# (rYY.MM) so the repoagent ABI matches the runtime.
ARG TRITON_VERSION=26.06
# Runtime base. Defaults to NGC; override to your mirror, e.g.
#   --build-arg BASE_IMAGE=597088022503.dkr.ecr.us-west-2.amazonaws.com/skopeo/nvidia/tritonserver:26.06-py3
ARG BASE_IMAGE=nvcr.io/nvidia/tritonserver:${TRITON_VERSION}-py3

FROM ubuntu:latest AS builder

ARG TRITON_VERSION

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    zip \
    unzip \
    tar \
    pkg-config \
    python3

RUN git clone https://github.com/Microsoft/vcpkg.git /vcpkg \
    && /vcpkg/bootstrap-vcpkg.sh

# Release-only triplet overlay: skips the failing debug build (and halves build time).
COPY ./triplets /vcpkg-triplets
ENV VCPKG_OVERLAY_TRIPLETS=/vcpkg-triplets

RUN /vcpkg/vcpkg install re2
RUN /vcpkg/vcpkg install grpc
RUN /vcpkg/vcpkg install aws-sdk-cpp
RUN /vcpkg/vcpkg install google-cloud-cpp[storage]
RUN /vcpkg/vcpkg install azure-storage-blobs-cpp
RUN /vcpkg/vcpkg install rapidjson

RUN mkdir -p /dragonfly-repository-agent/build

COPY ./src /dragonfly-repository-agent/src
COPY ./cmake /dragonfly-repository-agent/cmake
COPY ./CMakeLists.txt /dragonfly-repository-agent/CMakeLists.txt

WORKDIR /dragonfly-repository-agent/build

ENV VCPKG_TOOLCHAIN_FILE=/vcpkg/scripts/buildsystems/vcpkg.cmake

# Pin triton core/common to the release branch matching the runtime (rYY.MM).
RUN cmake -DCMAKE_TOOLCHAIN_FILE=${VCPKG_TOOLCHAIN_FILE} \
          -DCMAKE_INSTALL_PREFIX:PATH=`pwd`/install \
          -DTRITON_COMMON_REPO_TAG=r${TRITON_VERSION} \
          -DTRITON_CORE_REPO_TAG=r${TRITON_VERSION} \
          -DTRITON_ENABLE_GCS=true \
          -DTRITON_ENABLE_AZURE_STORAGE=true \
          -DTRITON_ENABLE_S3=true \
          -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
          ..

RUN make install

FROM ${BASE_IMAGE}

RUN mkdir /opt/tritonserver/repoagents/dragonfly

EXPOSE 8000
EXPOSE 8001
EXPOSE 8002

COPY --from=builder /dragonfly-repository-agent/build/libtritonrepoagent_dragonfly.so /opt/tritonserver/repoagents/dragonfly/libtritonrepoagent_dragonfly.so
