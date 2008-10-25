
BASEDIR ?= ..
include $(BASEDIR)/config

all: libs tools modules
clean libs tools modules:
	cd teklib && $(MAKE) $@
	cd hal && $(MAKE) $@
	cd exec && $(MAKE) $@
	cd visual && $(MAKE) $@
	cd display_x11 && $(MAKE) $@
#	cd display_dfb && $(MAKE) $@
#	cd io && $(MAKE) $@
#	cd datatype && $(MAKE) $@
