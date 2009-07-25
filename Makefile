
OPTIONS=--with-minify --with-uglify --with-compile --with-virtual-io

squish: squish.lua squishy
	./squish.lua $(OPTIONS)
	
install: squish
	install squish /usr/local/bin/squish

clean:
	rm squish
