NO_EXPAT = YesPlease
NO_GETTEXT = YesPlease
NO_TCLTK = YesPlease
NO_DAEMON = YesPlease
NO_SVN = YesPlease
NO_P4 = YesPlease
NO_CVS = YesPlease
NO_PERL = YesPlease
NO_EMAIL = YesPlease
NO_SCALAR = YesPlease
NO_GITWEB = YesPlease

USE_CURL = YesPlease
USE_OPENSSL = YesPlease
NO_CURL = 
NO_OPENSSL =

CURLDIR = $(PREFIX)/i486-linux-musl
OPENSSLDIR = $(PREFIX)/i486-linux-musl

EXTLIBS += -lcurl -lssl -lcrypto -lz -latomic -lpthread
LIBS += -lcurl -lssl -lcrypto -lz -latomic -lpthread

