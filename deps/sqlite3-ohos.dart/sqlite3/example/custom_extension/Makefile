vendor:
	mkdir -p vendor
	curl -o sqlite-amalgamation.zip https://www.sqlite.org/2024/sqlite-amalgamation-3450300.zip
	unzip sqlite-amalgamation.zip
	mv sqlite-amalgamation-3450300/* vendor/
	rmdir sqlite-amalgamation-3450300
	rm sqlite-amalgamation.zip

deps: sqlite3ext.h sqlite3.h

init: vendor deps

sqlite3ext.h: ./vendor/sqlite3ext.h
		cp $< $@
		mv sqlite3ext.h src/

sqlite3.h: ./vendor/sqlite3.h
		cp $< $@
		mv sqlite3.h src/

.PHONY: deps
