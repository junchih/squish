
OPTIONS=-q --with-minify --with-uglify --with-compile --with-virtual-io

squish: squish.lua squishy
	./squish.lua $(OPTIONS) # Bootstrap squish
	chmod +x squish
	./squish -q debug # Minify debug code
	./squish $(OPTIONS) --with-debug # Build squish with minified debug
	
install: squish
	install squish /usr/local/bin/squish

clean:
	rm squish squish.debug
