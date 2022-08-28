
DESTDIR=/usr/local
OPTIONS=-q --with-minify --with-uglify --with-compile --with-virtual-io

squish: squish.lua squishy
	./squish.lua $(OPTIONS) # Bootstrap squish
	chmod +x squish
	./squish -q gzip/squishy # Minify gunzip code
	./squish -q debug/squishy # Minify debug code
	./squish $(OPTIONS) --with-gzip --with-debug # Build squish with minified gzip/debug
	
install: squish
	install squish $(DESTDIR)/bin/squish
	install make_squishy $(DESTDIR)/bin/make_squishy

clean:
	rm squish squish.debug gunzip.lua
