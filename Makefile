################## Configuration parameters
# Compile using ocamlopt, to use ocamlc set TARGET=byte
TARGET=opt
# Install prefix
PREFIX=/usr/local
# Library directory of hevea
LIBDIR=$(PREFIX)/lib/hevea
# Where to install programms
BINDIR=$(PREFIX)/bin
# Install prefix prefix
DESTDIR=
#Where to install hevea.sty
LATEXLIBDIR=$(PREFIX)/lib/hevea
############### End of configuration parameters
SUF=.opt
DIR=
OCAMLC=$(DIR)ocamlc$(SUF)
OCAMLFLAGS=
#OCAMLFLAGS=-g -w ZY
OCAMLCI=$(OCAMLC)
OCAMLOPT=$(DIR)ocamlopt$(SUF)
OCAMLLEX=$(DIR)ocamllex$(SUF) -q
INSTALL=cp
MKDIR=mkdir -p

ONLYESPONJA=emisc.cmo buff.cmo pp.cmo htmllex.cmo htmlparse.cmo htmltext.cmo util.cmo explode.cmo ultra.cmo esponja.cmo

OBJS=version.cmo mysys.cmo myStack.cmo location.cmo misc.cmo  element.cmo out.cmo table.cmo mylib.cmo parse_opts.cmo  myfiles.cmo outUnicode.cmo save.cmo auxx.cmo  lexstate.cmo subst.cmo latexmacros.cmo counter.cmo noimage.cmo image.cmo length.cmo  get.cmo tabular.cmo htmlCommon.cmo htmlMath.cmo mathML.cmo html.cmo  text.cmo infoRef.cmo info.cmo section.cmo foot.cmo entry.cmo index.cmo colscan.cmo color.cmo hot.cmo package.cmo videoc.cmo verb.cmo latexscan.cmo zyva.cmo $(ONLYESPONJA) hevea.cmo
OBJSCUT=version.cmo mysys.cmo myStack.cmo location.cmo misc.cmo  out.cmo cutOut.cmo thread.cmo cross.cmo mylib.cmo section.cmo length.cmo save.cmo cut.cmo hacha.cmo
OBJSESPONJA=mysys.cmo myStack.cmo location.cmo $(ONLYESPONJA)  esponjamain.cmo
OBJSBIBHVA=bibhva.cmo

GENSRC=colscan.ml cut.ml entry.ml get.ml latexscan.ml length.ml save.ml tabular.ml videoc.ml verb.ml infoRef.ml subst.ml htmllex.ml

OPTS=$(OBJS:.cmo=.cmx)
OPTSCUT=$(OBJSCUT:.cmo=.cmx)
OPTSESPONJA=$(OBJSESPONJA:.cmo=.cmx)
OPTSBIBHVA=$(OBJSBIBHVA:.cmo=.cmx)
include libs.def

all: $(TARGET)
everything: byte opt

install: config.sh
	./install.sh $(TARGET)

opt:
	$(MAKE) $(MFLAGS) TARGET=opt hevea.opt hacha.opt esponja.opt bibhva.opt

byte:
	$(MAKE) $(MFLAGS) TARGET=byte hevea.byte hacha.byte esponja.byte bibhva.byte


hevea.byte: ${OBJS}
	${OCAMLC}  ${OCAMLFLAGS} -o $@ ${OBJS}

hacha.byte: ${OBJSCUT}
	${OCAMLC} ${OCAMLFLAGS} -o $@ ${OBJSCUT}

esponja.byte: ${OBJSESPONJA}
	${OCAMLC} ${OCAMLFLAGS} -o $@ ${OBJSESPONJA}

bibhva.byte: ${OBJSBIBHVA}
	${OCAMLC} ${OCAMLFLAGS} -o $@ ${OBJSBIBHVA}

hevea.opt: ${OPTS}
	${OCAMLOPT} -o $@ ${OPTS}

hacha.opt: ${OPTSCUT}
	${OCAMLOPT} -o $@ ${OPTSCUT}

esponja.opt: ${OPTSESPONJA}
	${OCAMLOPT} -o $@ ${OPTSESPONJA}

bibhva.opt: ${OPTSBIBHVA}
	${OCAMLOPT} -o $@ ${OPTSBIBHVA}

mylib.cmo: mylib.ml mylib.cmi config.sh
	${OCAMLC} ${OCAMLFLAGS} -pp ./expandlib.sh -c mylib.ml

mylib.cmx: mylib.ml mylib.cmi config.sh
	${OCAMLOPT} -pp ./expandlib.sh -c mylib.ml

fmt_map: fmt_map.cmo
	${OCAMLC} -o fmt_map fmt_map.cmo

config.sh: Makefile
	@( echo BINDIR=$(BINDIR) &&\
	echo LIBDIR=$(LIBDIR) &&\
	echo DESTDIR=$(DESTDIR) &&\
	echo LATEXLIBDIR=$(LATEXLIBDIR) &&\
	echo OCAMLFLAGS=\"$(OCAMLFLAGS)\" &&\
	echo ALLLIB=\"$(ALLLIB)\" && \
	echo HTMLLIB=\"$(HTMLLIB)\" && \
	echo TEXTLIB=\"$(TEXTLIB)\" && \
	echo INFOLIB=\"$(INFOLIB)\" ) > $@

clean::
	ocamlbuild -clean
	/bin/rm -f config.sh

ocb-byte:
	sh ocb.sh byte

ocb-opt:
	sh ocb.sh opt

ocb:config.sh
	sh ocb.sh $(TARGET)


.SUFFIXES:
.SUFFIXES: .ml .cmo .mli .cmi .c .mll .cmx 

.mll.ml:
	${OCAMLLEX} $<

.ml.cmx:
	${OCAMLOPT} -c $<

.ml.cmo:
	${OCAMLC}  ${OCAMLFLAGS} -c $<

.mli.cmi:
	${OCAMLCI} -c $<

.c:
	$(CC) $(CFLAGS) -o $@ $<

cleanbyte:
	rm -f *.byte
	rm -f *.cmo

clean::
	rm -f *.byte *.opt
	rm -f $(GENSRC) fmt_map.ml
	rm -f *.o *.cmi *.cmo *.cmx *.o *.ppo *.ppi
	rm -f *~ #*# html/*~ html/#*# text/*~ text/#*# info/*~ info/#*# 

depend: $(GENSRC)
	- cp .depend .depend.bak
	ocamldep *.mli *.ml > .depend

videoc.cmi : latexscan.cmi
videoc.cmo : videoc.cmi
include .depend
