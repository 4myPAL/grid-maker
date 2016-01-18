FROM msaraiva/elixir-dev:1.1.1

ENV BUILD_PATH /tmp/stratege_trading
ENV HEX_CDN https://hex.peatio.com:6443
ENV MIX_ENV prod

RUN mkdir -p $BUILD_PATH
WORKDIR $BUILD_PATH

COPY deps $BUILD_PATH/deps/
COPY config $BUILD_PATH/config/
COPY lib $BUILD_PATH/lib/
COPY mix.exs mix.lock $BUILD_PATH/

RUN mix deps.get && \
    mix compile && \
    mix release && \
    cp -rf rel/grid_maker /opt/ && \
    cd / && \
    rm -rf $BUILD_PATH && \
    rm /opt/grid_maker/releases/*/*.tar.gz

CMD /opt/grid_maker/bin/grid_maker foreground
