include $(CONFIG)

PKG_NAME=fix

CSRCS += \
	fix.c


INCLUDE	+= -I$(CURDIR)

VPATH	+= $(CURDIR)

DEFINE += -D__HAVE_LOCALE_INFO__
DEFINE += -D__HAVE_LOCALE_INFO_EXTENDED__

include $(TOPDIR)/make/build-lib.mk
