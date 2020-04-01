OPENRESTY_PREFIX=/usr/local/openresty

PREFIX ?=			/usr/local
LUA_INCLUDE_DIR ?=	$(PREFIX)/include
LUA_LIB_DIR ?=		$(OPENRESTY_PREFIX)/lualib/$(LUA_VERSION)
INSTALL ?=			install

.PHONY: all test install

all: ;

install: all
	$(INSTALL) -d $(DESTDIR)/$(LUA_LIB_DIR)/resty/pubsub
	$(INSTALL) lib/resty/pubsub/*.lua $(DESTDIR)/$(LUA_LIB_DIR)/resty/pubsub

test: all
	PATH=$(OPENRESTY_PREFIX)/nginx/sbin:$$PATH prove -I ./../test-nginx/lib -r t/