FROM ocurrent/opam:debian-10-ocaml-4.10@sha256:12fac4e3520657aa72074d2a3b2658776d4b3ce486c930099c996d478c3a2501 AS build
RUN sudo apt-get update && sudo apt-get install libev-dev capnproto m4 pkg-config libsqlite3-dev libgmp-dev -y --no-install-recommends
RUN cd ~/opam-repository && git pull origin -q master && git reset --hard e132600d1ea27a5be1edfb0079a205ba05830b8e && opam update
COPY --chown=opam ocluster-api.opam ocluster.opam /src/
WORKDIR /src
RUN opam install -y --deps-only .
ADD --chown=opam . .
RUN opam config exec -- dune build \
  ./_build/install/default/bin/ocluster-scheduler \
  ./_build/install/default/bin/ocluster-admin

FROM debian:10
RUN apt-get update && apt-get install libev4 libsqlite3-0 -y --no-install-recommends
WORKDIR /var/lib/ocluster-scheduler
ENTRYPOINT ["/usr/local/bin/ocluster-scheduler"]
COPY --from=build \
     /src/_build/install/default/bin/ocluster-scheduler \
     /src/_build/install/default/bin/ocluster-admin \
     /usr/local/bin/
